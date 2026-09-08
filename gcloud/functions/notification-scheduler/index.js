// Google Cloud Function for Notification Scheduling
// Handles expiring ingredients and inactivity reminders.

const { MongoClient, ObjectId } = require("mongodb");

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";

let client;

async function connectToMongo() {
  if (!MONGODB_URI) {
    throw new Error("MONGODB_URI environment variable is not set");
  }

  if (client && client.topology && client.topology.isConnected()) {
    console.log("Reusing existing MongoDB connection");
    return client.db(DB_NAME);
  }

  try {
    console.log("Attempting to connect to MongoDB...");
    client = new MongoClient(MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 5000,
    });
    await client.connect();
    console.log("Successfully connected to MongoDB");
    return client.db(DB_NAME);
  } catch (error) {
    console.error("Failed to connect to MongoDB:", error);
    if (client) {
      await client.close();
      client = null;
    }
    throw new Error("Database connection failed");
  }
}

exports.notificationScheduler = async (req, res) => {
  try {
    const { type } = req.body || {};

    console.log(`[Notification Scheduler] Processing ${type} notifications`);

    let result;

    // expired_items has a scheduled sweep (checkExpiredItems) alongside the
    // existing client-side detection in SimpleNotificationService --
    // both share the same per-item dedup ledger
    // (pantry_items.expiredNotifiedAt), so neither path can double-notify
    // about the same expired item. See checkExpiredItems()'s doc comment
    // for the full reasoning.
    switch (type) {
      case "expiring_ingredients":
        result = await checkExpiringIngredients();
        break;
      case "expired_items":
        result = await checkExpiredItems();
        break;
      case "tracker_reminder":
        result = await checkMealLoggingInactivityReminders();
        break;
      case "app_inactivity_reminder":
        result = await checkAppInactivityReminders();
        break;
      case "meal_reminder_fallback":
        result = await checkMealReminderFallbacks();
        break;
      case "run_all":
        result = await runAllNotificationChecks();
        break;
      case "test":
        result = {
          status: "success",
          message: "Test notification scheduler is working!",
        };
        break;
      default:
        return res.status(400).json({
          error:
            "Invalid notification type. Use: expiring_ingredients, expired_items, tracker_reminder, app_inactivity_reminder, meal_reminder_fallback, run_all, or test",
        });
    }

    res.status(200).json(result);
  } catch (error) {
    console.error("Error in notification scheduler:", error);
    res.status(500).json({ error: error.message });
  }
};

const MEAL_LOGGING_DAY_MILESTONES = [1, 2, 3, 4, 5, 6];
const MEAL_LOGGING_WEEK_MILESTONES = [7, 14, 21, 28];
const MEAL_LOGGING_MONTH_MILESTONES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

const APP_OPEN_DAY_MILESTONES = [1, 2, 3, 4, 5, 6];
const APP_OPEN_WEEK_MILESTONES = [7, 14, 21, 28];
const APP_OPEN_MONTH_MILESTONES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const NEW_ACCOUNT_GRACE_HOURS = 24;

// Generic server-side fallback meal reminders for lunch/dinner, for
// whichever of those two meals the user has NOT personally enabled a
// reminder for (breakfast/lunch/dinner reminders are otherwise scheduled
// entirely client-side -- see lib/core/services/notification_service.dart --
// and never pass through this pipeline). No breakfast fallback exists by
// design. Each meal is evaluated fully independently; see
// decideMealReminderFallback().
//
// Target local times, in minutes since local midnight. A floor, not a fixed
// slot -- once local time crosses this, the fallback stays eligible for the
// rest of the day (mirrors PANTRY_PREFERRED_LOCAL_MINUTES in
// notification-delivery/index.js, chosen specifically because that pattern
// is documented there as cadence-independent, which this must also be since
// the actual Cloud Scheduler cadence isn't tracked in this repo).
const MEAL_FALLBACK_TARGET_MINUTES = {
  lunch: 12 * 60 + 30, // 12:30 PM local
  dinner: 18 * 60, // 6:00 PM local
};

// Local-time windows (minutes since local midnight) used to approximate
// "was this specific meal already logged today." There is no meal-type
// field anywhere in the data model -- tracker updates
// (user_trackers/tracker_progress) are cumulative nutrient/category
// counters with no meal-of-day tagging, client or server side. This reuses
// the exact same "latest tracker activity" signal
// checkMealLoggingInactivityReminders already uses for its own "logged
// today" check, just scoped to a meal-specific window instead of "any time
// today." This is necessarily an approximation -- any tracker activity
// landing in the window counts as "logged", not specifically an activity
// caused by logging that meal -- accepting the same imprecision the
// existing tracker_reminder check already lives with for its own
// all-activity signal.
const MEAL_LOG_WINDOW_MINUTES = {
  lunch: [11 * 60, 14 * 60 + 30], // 11:00 AM - 2:30 PM
  dinner: [16 * 60, 18 * 60 + 30], // 4:00 PM - 6:30 PM
};

const MEAL_FALLBACK_COPY = {
  lunch: {
    title: "Time to log your meal",
    message:
      "Take a moment to log your servings in MyFoodRx and keep your nutrition record up to date.",
  },
  dinner: {
    title: "Don't forget to log your meal",
    message:
      "Take a moment to log your servings in MyFoodRx and keep today's nutrition record complete.",
  },
};

function mealReminderFallbackType(meal) {
  return `${meal}_reminder_fallback`;
}

// Milestone day-count, using the user's LOCAL calendar day (localDayStartUtc,
// defined below) rather than the server runtime's timezone. Cloud Functions
// run in UTC, so without this every user's "days since last log" would
// silently be computed against UTC calendar-day boundaries instead of their
// own -- the same bug class localDayStartUtc already exists to prevent for
// same-day dedupe checks elsewhere in this file.
//
// Returns the number of LOCAL CALENDAR DAY boundaries crossed between
// `earlier` and `later` -- not elapsed 24-hour periods. Do not simplify
// this to Math.floor((later - earlier) / DAY_MS); that reintroduces the
// timezone bug this function exists to fix.
function dayDiffFloor(later, earlier, timezoneOffsetMinutes) {
  const msPerDay = 24 * 60 * 60 * 1000;
  const laterStart = localDayStartUtc(later, timezoneOffsetMinutes);
  const earlierStart = localDayStartUtc(earlier, timezoneOffsetMinutes);
  return Math.floor((laterStart.getTime() - earlierStart.getTime()) / msPerDay);
}

// Adds `months` to `date`'s LOCAL calendar day, clamping day-of-month
// overflow to the last day of the target month (e.g. Jan 31 + 1 month ->
// Feb 28/29, not Mar 3 -- the standard setMonth() overflow idiom), but
// anchored to the user's local calendar instead of the server's. Returns
// that target day's local midnight, expressed back in UTC, so it can be
// compared directly against another localDayStartUtc() value.
function addMonthsLocalDayStartUtc(date, months, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  const local = new Date(date.getTime() + offsetMs);
  const originalDay = local.getUTCDate();
  local.setUTCMonth(local.getUTCMonth() + months);
  if (local.getUTCDate() < originalDay) {
    local.setUTCDate(0);
  }
  const localMidnightUtc = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  return new Date(localMidnightUtc - offsetMs);
}

function getInactivityBucket(
  now,
  referenceDate,
  dayMilestones,
  weekMilestones,
  monthMilestones,
  timezoneOffsetMinutes
) {
  if (!referenceDate) return null;

  const days = dayDiffFloor(now, referenceDate, timezoneOffsetMinutes);
  if (days <= 0) return null;

  for (const d of dayMilestones) {
    if (days === d) {
      return { key: `d${d}`, days };
    }
  }

  for (const w of weekMilestones) {
    if (days === w) {
      return { key: `w${w / 7}`, days };
    }
  }

  const todayLocalStart = localDayStartUtc(now, timezoneOffsetMinutes);
  for (const m of monthMilestones) {
    const targetLocalStart = addMonthsLocalDayStartUtc(referenceDate, m, timezoneOffsetMinutes);
    if (targetLocalStart.getTime() === todayLocalStart.getTime()) {
      return { key: `m${m}`, days };
    }
  }

  return null;
}

function bucketLabel(bucketKey) {
  if (!bucketKey || bucketKey.length < 2) return "";
  const kind = bucketKey[0];
  const value = parseInt(bucketKey.slice(1), 10);
  if (Number.isNaN(value)) return "";
  // Singular reads as prose ("a day"), plural as a numeral ("2 days") --
  // matches how the milestone count is actually meant to be read.
  if (kind === "d") return value === 1 ? "a day" : `${value} days`;
  if (kind === "w") return value === 1 ? "a week" : `${value} weeks`;
  if (kind === "m") return value === 1 ? "a month" : `${value} months`;
  return "";
}

// Leads with the call to action, then names the "why" (time since
// sincePhrase) last, so the reminder still reads as personalized instead of
// a generic "It's been 1 day." with no context of what that's since.
function formatMessageWithReason(callToAction, sincePhrase, bucketKey) {
  const label = bucketLabel(bucketKey);
  if (!label) return callToAction;
  return `${callToAction} It's been ${label} since ${sincePhrase}.`;
}

// Tracker-inactivity-ladder body copy: leads with the time-since clause
// instead of a call to action (deliberately the opposite ordering from
// formatMessageWithReason, which App Inactivity still uses unchanged --
// this is a separate function, not a restructuring of that shared one, so
// App Inactivity's copy is unaffected).
function formatTrackerInactivityBody(bucketKey) {
  const label = bucketLabel(bucketKey);
  if (!label) return "Check in when you're ready.";
  return `It's been ${label} since you last logged a meal. Check in when you're ready.`;
}

// Decides which (if any) tracker reminder a single user should get today,
// given their latest logging activity. Encodes two priority rules in one
// place so they're unit-testable without a live Mongo connection:
//   1. The inactivity ladder takes priority over the same-day daily
//      reminder -- never send both.
//   2. The daily ("d0") reminder is suppressed entirely when the user has
//      Meal Reminders enabled -- they already get a configured
//      breakfast/lunch/dinner (or generic) nudge for "haven't logged
//      today", so this would be redundant. This mirrors, and is separate
//      from, the d1 ladder milestone's own meal-reminder suppression above.
// Does NOT perform the once-per-bucket-ever or once-per-local-day dedupe
// checks (those need the database) -- callers must still run those before
// actually inserting a document. Returns null if nothing should be sent.
function decideTrackerReminder(now, latestDate, mealRemindersEnabled, timezoneOffsetMinutes) {
  if (latestDate) {
    const bucket = getInactivityBucket(
      now,
      latestDate,
      MEAL_LOGGING_DAY_MILESTONES,
      MEAL_LOGGING_WEEK_MILESTONES,
      MEAL_LOGGING_MONTH_MILESTONES,
      timezoneOffsetMinutes
    );
    // Day 1 is already covered by the user's own meal reminders when
    // enabled; days 2-6, weekly and monthly milestones still fire
    // regardless, since a user ignoring meal reminders for that long is a
    // distinct "fell out of the habit" signal worth surfacing.
    const skipDueToMealReminders = bucket?.key === "d1" && mealRemindersEnabled === true;
    if (bucket && !skipDueToMealReminders) {
      return {
        kind: "inactivity",
        bucketKey: bucket.key,
        daysSinceLastLog: bucket.days,
        title: "Your nutrition log is waiting",
        message: formatTrackerInactivityBody(bucket.key),
      };
    }
  }

  // dayDiffFloor(now, latestDate, ...) <= 0 means the latest activity's
  // local day is today (or later, which can't happen) -- i.e. already
  // logged today, so no daily reminder is needed either.
  const loggedToday =
    latestDate != null && dayDiffFloor(now, latestDate, timezoneOffsetMinutes) <= 0;
  if (loggedToday) return null;

  // A user with Meal Reminders enabled already gets their own configured
  // breakfast/lunch/dinner (or generic) nudge for "haven't logged today" --
  // sending this daily reminder too would be redundant. Matches the d1
  // ladder milestone's existing suppression above, extended to the daily
  // reminder per product decision.
  if (mealRemindersEnabled === true) return null;

  return {
    kind: "daily",
    bucketKey: "d0",
    title: "Ready to log today's meals?",
    message: "You haven't logged anything today. Take a moment to update your nutrition record.",
  };
}

// Picks the more recent of several raw date-like values (e.g.
// tracker_progress's progressDate and user_trackers' lastUpdated),
// tolerating any of them being missing or unparseable. Extracted out of
// checkMealLoggingInactivityReminders so the "use whichever activity
// signal is fresher" rule has one unit-testable home instead of living
// inline in the per-user loop.
// Single-item expiring-soon heading: keeps the today/tomorrow/N-days urgency
// signal in the *heading* (the body is now fixed regardless of day count --
// see checkExpiringIngredients). Mirrors
// SimpleNotificationService.expiringItemHeading (Dart) -- keep both in sync.
function expiringSoonHeading(itemName, daysUntilExpiry) {
  if (daysUntilExpiry <= 0) return `${itemName} expires today`;
  if (daysUntilExpiry === 1) return `${itemName} expires tomorrow`;
  return `${itemName} expires in ${daysUntilExpiry} days`;
}

// Truncates a multi-item digest body to the first 3 item names plus an
// "and N more" tail. Mirrors
// SimpleNotificationService.expiringItemsListSummary (Dart) -- keep both in
// sync.
function expiringItemsListSummary(names) {
  const maxNames = 3;
  const shown = names.slice(0, maxNames);
  const remaining = names.length - shown.length;
  return remaining > 0 ? `${shown.join(", ")} and ${remaining} more` : shown.join(", ");
}

// Decides the expired_items digest for a single user, given the names/ids
// of their currently-expired pantry items and which of those ids were
// already notified about before (pantry_items.expiredNotifiedAt -- the same
// ledger field and semantics as the client-side path in
// POST /notifications, backend/app/routers/notifications.py). Pure
// function, no DB access, so the "push once per item, Center-only digest
// once nothing is new" rule is unit-testable without a live Mongo
// connection. `itemIds` and `alreadyNotifiedIds` are plain hex-string ids
// (callers convert to/from ObjectId around this call) so tests don't need
// a Mongo driver either.
//
// pushEligible=false means "every item in today's expired set was already
// notified before" -- the caller should still create a Notification Center
// doc (so it reflects current pantry state) but stamp it with sentAt
// immediately so notification-delivery's sweep never pushes it, avoiding a
// daily nag about the same still-unresolved expired item.
function decideExpiredItemsDigest(itemNames, itemIds, alreadyNotifiedIds) {
  const alreadyNotified =
    alreadyNotifiedIds instanceof Set ? alreadyNotifiedIds : new Set(alreadyNotifiedIds);
  const title = itemNames.length === 1 ? `${itemNames[0]} has expired` : "Some items have expired";
  const message =
    itemNames.length === 1
      ? "Review its expiration date and update it if needed."
      : `${expiringItemsListSummary(itemNames)}. Review the expiration dates and update them if needed.`;
  const idsToMark = itemIds.filter((id) => !alreadyNotified.has(id));
  return {
    title,
    message,
    pushEligible: idsToMark.length > 0,
    idsToMark,
  };
}

function resolveLatestActivityDate(...rawDates) {
  let latest = null;
  for (const raw of rawDates) {
    if (!raw) continue;
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) continue;
    if (!latest || d > latest) latest = d;
  }
  return latest;
}

// Maps a notification's `type` to the key inside a user's
// notificationTypePrefs map that controls it. Mirrors
// notification_eligibility.NOTIFICATION_TYPE_TO_PREF_KEY (Python) and the
// equivalent map in notification-delivery/index.js (the final send-time
// gate). "app_inactivity_reminder" is deliberately absent -- there is no
// dedicated Notification Settings toggle for it yet, so it is left
// ungated here; see the notification-system implementation notes.
const NOTIFICATION_TYPE_TO_PREF_KEY = {
  expiring_ingredient: "expiringIngredients",
  expired_items: "expiringIngredients",
  tracker_reminder: "trackerReminders",
  education: "education",
  admin: "adminUpdates",
};

function isNotificationTypeEnabled(user, type) {
  const prefKey = NOTIFICATION_TYPE_TO_PREF_KEY[type];
  if (!prefKey) return true;
  const prefs = user?.notificationTypePrefs || {};
  return prefs[prefKey] !== false;
}

// Mirrors lib/core/utils/meal_reminder_prefs.dart's isMealRemindersMasterEnabled
// / mealReminderOwnEnabled / isMealReminderEnabled -- kept in sync by hand,
// same as every other cross-language mirror in this file. `enabled` at the
// top level is the master "Meal reminders" switch: when false, every meal
// is off regardless of its own flag. A meal whose own `enabled` key is
// present is authoritative once the master is on -- an explicit per-meal
// `false` stays disabled even if a stale top-level `enabled: true` also
// exists on the doc. Only a genuinely old-format doc (no per-meal `enabled`
// key at all, from before this preference structure changed) falls back to
// the single top-level flag for that meal.
function isMealRemindersMasterEnabled(prefs) {
  return prefs != null && prefs.enabled === true;
}

function mealReminderOwnEnabled(prefs, meal) {
  const mealPrefs = prefs ? prefs[meal] : null;
  if (
    mealPrefs &&
    typeof mealPrefs === "object" &&
    Object.prototype.hasOwnProperty.call(mealPrefs, "enabled")
  ) {
    return mealPrefs.enabled === true;
  }
  return prefs != null && prefs.enabled === true;
}

function isPersonalizedMealReminderEnabled(prefs, meal) {
  return isMealRemindersMasterEnabled(prefs) && mealReminderOwnEnabled(prefs, meal);
}

// Whether the user has a personalized reminder actually configured for AT
// LEAST ONE meal. This -- not the bare master switch -- is what
// decideTrackerReminder()'s mealRemindersEnabled parameter must mean: the
// master switch can be on with every individual meal off (e.g. right after
// the reset-on-master-off behavior in the Flutter settings page, or before
// the user has picked any meal yet), and in that state no personalized
// reminder fires for anything. Passing the bare master flag there would
// suppress this daily fallback too, leaving the user with zero reminders
// until lunch/dinner's own server-side fallback window opens (and no
// coverage at all for breakfast, which has no fallback) -- a real
// notification blackout. Checking all three meals here closes that gap.
function hasAnyPersonalizedMealReminderEnabled(prefs) {
  return ["breakfast", "lunch", "dinner"].some((meal) =>
    isPersonalizedMealReminderEnabled(prefs, meal)
  );
}

// Mirrors notification-delivery/index.js's localMinutesOfDay (same
// no-shared-package mirroring convention as every other timezone helper in
// this file).
function localMinutesOfDay(nowUtc, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  const local = new Date(nowUtc.getTime() + offsetMs);
  return local.getUTCHours() * 60 + local.getUTCMinutes();
}

// Decides whether a single meal's generic fallback reminder should be
// created "right now" for one user. Pure, no DB access, so all preference
// combinations and the specific logging-window examples are unit-testable
// without a live Mongo connection -- mirrors decideTrackerReminder /
// decideExpiredItemsDigest. Does NOT perform the once-per-user-per-local-day
// dedupe (needs the database) -- callers must still run
// findTodaysNotification first.
//
//   meal                  - "lunch" or "dinner"
//   mealPrefs             - user.mealLoggingReminderPrefs (old- or
//                           new-format, or null/undefined)
//   now                   - current UTC Date
//   latestActivityDate    - resolveLatestActivityDate() of this user's
//                           tracker_progress.progressDate and
//                           user_trackers.lastUpdated (same signal
//                           checkMealLoggingInactivityReminders uses)
//   timezoneOffsetMinutes - user.timezoneOffsetMinutes
function decideMealReminderFallback(meal, mealPrefs, now, latestActivityDate, timezoneOffsetMinutes) {
  // Personalized reminder takes precedence -- no fallback needed at all,
  // regardless of what the other meal's toggle is set to.
  if (isPersonalizedMealReminderEnabled(mealPrefs, meal)) return null;

  const nowMinutes = localMinutesOfDay(now, timezoneOffsetMinutes);
  const targetMinutes = MEAL_FALLBACK_TARGET_MINUTES[meal];
  // Floor, not a fixed slot -- see MEAL_FALLBACK_TARGET_MINUTES's doc comment.
  if (nowMinutes < targetMinutes) return null;

  // Approximate "already logged this meal": any tracker activity whose
  // local day is today and whose local minute-of-day falls inside this
  // meal's window (see MEAL_LOG_WINDOW_MINUTES's doc comment for the
  // approximation this represents).
  if (latestActivityDate) {
    const sameLocalDay = dayDiffFloor(now, latestActivityDate, timezoneOffsetMinutes) <= 0;
    if (sameLocalDay) {
      const activityMinutes = localMinutesOfDay(latestActivityDate, timezoneOffsetMinutes);
      const [windowStart, windowEnd] = MEAL_LOG_WINDOW_MINUTES[meal];
      if (activityMinutes >= windowStart && activityMinutes <= windowEnd) {
        return null;
      }
    }
  }

  const copy = MEAL_FALLBACK_COPY[meal];
  return { title: copy.title, message: copy.message };
}

function isWithinNewAccountGracePeriod(now, user) {
  const rawCreatedAt = user?.createdAt;
  if (!rawCreatedAt) return false;
  const createdAt = new Date(rawCreatedAt);
  if (Number.isNaN(createdAt.getTime())) return false;
  const ageMs = now.getTime() - createdAt.getTime();
  return ageMs >= 0 && ageMs < NEW_ACCOUNT_GRACE_HOURS * 60 * 60 * 1000;
}

// Start of the user's local calendar day, expressed back in UTC.
// `timezoneOffsetMinutes` follows the Dart `DateTime.timeZoneOffset` /
// JS `-Date.getTimezoneOffset()` convention: minutes to ADD to UTC to get
// local time. Mirrors `notification_eligibility.local_day_start_utc` on
// the Python side (same semantics, same default of 0/UTC when unset).
function localDayStartUtc(nowUtc, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  const localNow = new Date(nowUtc.getTime() + offsetMs);
  const localMidnightUtc = Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate());
  return new Date(localMidnightUtc - offsetMs);
}

// Finds an existing notification of `type` for `userId` created on/after
// `sinceUtc`, tolerating `createdAt` stored as either a native BSON Date
// (written by this Cloud Function) or an ISO string (written by the Python
// backend -- see backend/app/routers/notifications.py, which formats every
// createdAt via datetime.isoformat()). A plain `{createdAt: {$gte: ...}}`
// filter only matches Date-typed values against a Date operand, so it
// silently never found a same-day digest the *other* language's code path
// had already created -- letting a client-triggered digest and this
// scheduled sweep both fire for the same user on the same day instead of
// one updating the other in place. Mirrors the same $convert-to-date
// pattern notifications.py::list_notifications() already uses (for
// sorting) -- applied here for filtering instead.
async function findTodaysNotification(notificationsCollection, userId, type, sinceUtc) {
  const matches = await notificationsCollection
    .aggregate([
      { $match: { userId: userId, type: type } },
      {
        $addFields: {
          createdAtParsed: {
            $convert: { input: "$createdAt", to: "date", onError: new Date(0), onNull: new Date(0) },
          },
        },
      },
      { $match: { createdAtParsed: { $gte: sinceUtc } } },
      { $limit: 1 },
    ])
    .toArray();
  return matches[0] || null;
}

/**
 * Check for expiring pantry items (3 days before expiry)
 */
async function checkExpiringIngredients() {
  let db;
  try {
    db = await connectToMongo();
    const pantryCollection = db.collection("pantry_items");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Expiring Ingredients] Starting check");

    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    // Get total user count
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[Expiring Ingredients] Total users to check: ${totalUsers}`);

    // Process users in batches to avoid memory issues
    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      // Get next batch of users
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Expiring Ingredients] Processing batch: ${users.length} users (${processedUsers + users.length}/${totalUsers} total)`
      );

      for (const user of users) {
        const userId = user._id.toHexString();

        // Skip alerts for very new accounts to avoid noisy first-day nudges.
        if (isWithinNewAccountGracePeriod(now, user)) {
          continue;
        }

        // Respect the user's "Expiring Ingredients" Notification Settings toggle.
        if (!isNotificationTypeEnabled(user, "expiring_ingredient")) {
          continue;
        }

        // Get expiring items for this user (next 3 days)
        // expiryDate may be stored as ISO string; convert to Date for comparison
        const expiringItems = await pantryCollection
          .aggregate([
            {
              $match: {
                userId: user._id,
                expiryDate: { $exists: true, $ne: null },
              },
            },
            { $addFields: { expiryDateParsed: { $toDate: "$expiryDate" } } },
            {
              $match: { expiryDateParsed: { $lte: threeDaysFromNow, $gte: now } },
            },
          ])
          .toArray();

        if (expiringItems.length === 0) continue;

        const names = expiringItems
          .map((i) => (i.name || "").toString())
          .filter((n) => n.length > 0);

        const title =
          names.length === 1
            ? expiringSoonHeading(
                names[0],
                dayDiffFloor(expiringItems[0].expiryDateParsed, now, user.timezoneOffsetMinutes)
              )
            : `${names.length} items expire soon`;
        const message =
          names.length === 1
            ? "Check your pantry and use it before it expires."
            : `${expiringItemsListSummary(names)}. Check your pantry and use them before they expire.`;

        // If a digest exists today (in the user's local timezone), update it; otherwise insert new
        const today = localDayStartUtc(now, user.timezoneOffsetMinutes);

        const existing = await findTodaysNotification(
          notificationsCollection,
          userId,
          "expiring_ingredient",
          today
        );

        if (existing) {
          await notificationsCollection.updateOne(
            { _id: existing._id },
            { $set: { title, message, updatedAt: new Date() } }
          );
          console.log(
            `[Expiring Ingredients] Updated digest for user ${userId} with ${names.length} items`
          );
        } else {
          await notificationsCollection.insertOne({
            userId: userId,
            type: "expiring_ingredient",
            title,
            message,
            createdAt: new Date(),
          });
          notificationsCreated++;
        }
      }

      processedUsers += users.length;

      // If we got fewer users than the batch size, we've processed all
      if (users.length < BATCH_SIZE) {
        hasMore = false;
      }

      console.log(
        `[Expiring Ingredients] Batch complete. Progress: ${processedUsers}/${totalUsers} users processed, ${notificationsCreated} notifications created so far`
      );
    }

    console.log(
      `[Expiring Ingredients] Completed. Processed ${processedUsers} users, created ${notificationsCreated} notifications`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking expiring ingredients:", error);
    throw new Error(`Expiring ingredients check failed: ${error.message}`);
  }
}

/**
 * Check for already-expired pantry items.
 *
 * This is the scheduled, "app not opened" catch-all for expired_items --
 * added so a user who hasn't opened MyFoodRx still gets notified once an
 * item's expiration date has passed. It runs alongside, not instead of, the
 * existing client-side detection in SimpleNotificationService.checkExpiredItems
 * (fires when pantry data loads/refreshes on-device) -- that path stays for
 * the same reason expiring_ingredient keeps its own immediate pantry
 * add/edit check alongside this scheduled sweep: same-session detection
 * while the user is actively in the app is still valuable, and both paths
 * share the same per-item "already notified" ledger
 * (pantry_items.expiredNotifiedAt, also written/read by
 * POST /notifications in backend/app/routers/notifications.py), so neither
 * can double-notify about the same expired item regardless of which path
 * gets there first. See decideExpiredItemsDigest() for that dedup rule.
 */
async function checkExpiredItems() {
  let db;
  try {
    db = await connectToMongo();
    const pantryCollection = db.collection("pantry_items");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Expired Items] Starting check");

    const now = new Date();

    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[Expired Items] Total users to check: ${totalUsers}`);

    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Expired Items] Processing batch: ${users.length} users (${processedUsers + users.length}/${totalUsers} total)`
      );

      for (const user of users) {
        const userId = user._id.toHexString();

        // Skip alerts for very new accounts to avoid noisy first-day nudges.
        if (isWithinNewAccountGracePeriod(now, user)) {
          continue;
        }

        // expired_items shares the "Expiring Ingredients" Notification
        // Settings toggle with expiring_ingredient.
        if (!isNotificationTypeEnabled(user, "expired_items")) {
          continue;
        }

        const expiredItems = await pantryCollection
          .aggregate([
            {
              $match: {
                userId: user._id,
                expiryDate: { $exists: true, $ne: null },
              },
            },
            { $addFields: { expiryDateParsed: { $toDate: "$expiryDate" } } },
            { $match: { expiryDateParsed: { $lt: now } } },
          ])
          .toArray();

        if (expiredItems.length === 0) continue;

        // One expired_items document per user per local day -- mirrors the
        // same per-day guard checkExpiringIngredients uses for its type.
        const today = localDayStartUtc(now, user.timezoneOffsetMinutes);
        const existingToday = await findTodaysNotification(
          notificationsCollection,
          userId,
          "expired_items",
          today
        );
        if (existingToday) continue;

        const names = expiredItems
          .map((i) => (i.name || "").toString())
          .filter((n) => n.length > 0);
        const idStrings = expiredItems.map((i) => i._id.toHexString());

        const alreadyNotifiedDocs = await pantryCollection
          .find(
            { _id: { $in: expiredItems.map((i) => i._id) }, expiredNotifiedAt: { $exists: true } },
            { projection: { _id: 1 } }
          )
          .toArray();
        const alreadyNotifiedIds = new Set(alreadyNotifiedDocs.map((d) => d._id.toHexString()));

        const decision = decideExpiredItemsDigest(names, idStrings, alreadyNotifiedIds);

        const doc = {
          userId: userId,
          type: "expired_items",
          title: decision.title,
          message: decision.message,
          createdAt: new Date(),
        };

        if (decision.pushEligible) {
          await pantryCollection.updateMany(
            { _id: { $in: decision.idsToMark.map((id) => new ObjectId(id)) } },
            { $set: { expiredNotifiedAt: now } }
          );
        } else {
          // Nothing new since the last notification about this expired set
          // -- keep it Center-only, same as the client-side path's behavior.
          doc.sentAt = now;
        }

        await notificationsCollection.insertOne(doc);
        notificationsCreated++;
      }

      processedUsers += users.length;

      if (users.length < BATCH_SIZE) {
        hasMore = false;
      }

      console.log(
        `[Expired Items] Batch complete. Progress: ${processedUsers}/${totalUsers} users processed, ${notificationsCreated} notifications created so far`
      );
    }

    console.log(
      `[Expired Items] Completed. Processed ${processedUsers} users, created ${notificationsCreated} notifications`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking expired items:", error);
    throw new Error(`Expired items check failed: ${error.message}`);
  }
}

/**
 * Meal logging inactivity reminders.
 */
async function checkMealLoggingInactivityReminders() {
  let db;
  try {
    db = await connectToMongo();
    const progressCollection = db.collection("tracker_progress");
    const trackersCollection = db.collection("user_trackers");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Meal Logging Reminder] Starting check");

    const now = new Date();

    // Get total user count
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[Meal Logging Reminder] Total users to check: ${totalUsers}`);

    // Process users in batches to avoid memory issues
    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      // Get next batch of users
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Meal Logging Reminder] Processing batch: ${users.length} users (${processedUsers + users.length}/${totalUsers} total)`
      );

      for (const user of users) {
        const userId = user._id.toHexString();

        // Skip reminders for very new accounts to avoid noisy first-day nudges.
        if (isWithinNewAccountGracePeriod(now, user)) {
          continue;
        }

        // Respect the user's "Tracker Reminders" Notification Settings toggle.
        if (!isNotificationTypeEnabled(user, "tracker_reminder")) {
          continue;
        }

        // Only one tracker reminder notification per user per local day.
        const today = localDayStartUtc(now, user.timezoneOffsetMinutes);
        const existingToday = await findTodaysNotification(
          notificationsCollection,
          userId,
          "tracker_reminder",
          today
        );
        if (existingToday) {
          continue;
        }

        const latestProgress = await progressCollection
          .find({
            userId: userId,
          })
          .sort({ progressDate: -1 })
          .limit(1)
          .toArray();

        // tracker_progress only gains a row once a day, when that day's
        // trackers reset -- so on any given day, before tonight's reset
        // runs, its latest row is always ~1 day stale by construction, even
        // for a user actively logging meals right now. user_trackers is
        // updated live on every log (see PATCH /trackers/{id} -> lastUpdated
        // in trackers.py), so check it too and use whichever signal is more
        // recent as "last logged" -- otherwise every active user trips the
        // d1 bucket daily regardless of same-day logging.
        const latestTrackerUpdate = await trackersCollection
          .find({
            userId: userId,
          })
          .sort({ lastUpdated: -1 })
          .limit(1)
          .toArray();

        const latestDate = resolveLatestActivityDate(
          latestProgress[0]?.progressDate,
          latestTrackerUpdate[0]?.lastUpdated
        );

        const decision = decideTrackerReminder(
          now,
          latestDate,
          hasAnyPersonalizedMealReminderEnabled(user?.mealLoggingReminderPrefs),
          user.timezoneOffsetMinutes
        );
        if (!decision) {
          continue;
        }

        // The inactivity-ladder milestones each fire at most once ever per
        // user (unchanged from prior behavior); the daily ("d0") reminder
        // has no such lifetime dedupe -- it's meant to recur, and the
        // top-of-loop existingToday check already guarantees at most one
        // tracker_reminder of either kind per user per local day.
        if (decision.kind === "inactivity") {
          const existing = await notificationsCollection.findOne({
            userId: userId,
            type: "tracker_reminder",
            bucketKey: decision.bucketKey,
          });
          if (existing) {
            continue;
          }
        }

        const doc = {
          userId: userId,
          type: "tracker_reminder",
          title: decision.title,
          message: decision.message,
          bucketKey: decision.bucketKey,
          createdAt: new Date(),
        };
        if (decision.daysSinceLastLog !== undefined) {
          doc.daysSinceLastLog = decision.daysSinceLastLog;
        }
        await notificationsCollection.insertOne(doc);
        notificationsCreated++;
      }

      processedUsers += users.length;

      // If we got fewer users than the batch size, we've processed all
      if (users.length < BATCH_SIZE) {
        hasMore = false;
      }

      console.log(
        `[Meal Logging Reminder] Batch complete. Progress: ${processedUsers}/${totalUsers} users processed, ${notificationsCreated} reminders created so far`
      );
    }

    console.log(
      `[Meal Logging Reminder] Completed. Processed ${processedUsers} users, created ${notificationsCreated} reminders`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking meal logging inactivity reminders:", error);
    throw new Error(`Meal logging reminder check failed: ${error.message}`);
  }
}

/**
 * Generic server-side fallback meal reminders (lunch/dinner).
 *
 * For each of lunch and dinner independently: if the user has a
 * personalized reminder enabled for that specific meal (master switch on
 * AND that meal's own toggle on), no fallback is generated -- their
 * personalized (client-scheduled local) reminder already covers it. If
 * personalized is off for that meal, a generic fallback is eligible once
 * local time has passed that meal's target (12:30pm / 6:00pm) and the meal
 * hasn't already been "logged" per the local-time-window heuristic (see
 * decideMealReminderFallback). No breakfast fallback exists.
 *
 * NOT gated by any Notification Settings toggle -- same precedent as
 * checkAppInactivityReminders(): there is no dedicated preference for this
 * yet, and users already control it directly via the per-meal Meal
 * Reminders switches, so mapping it onto an unrelated existing toggle (e.g.
 * Tracker Reminders) would be an unreviewed product decision.
 */
async function checkMealReminderFallbacks() {
  let db;
  try {
    db = await connectToMongo();
    const progressCollection = db.collection("tracker_progress");
    const trackersCollection = db.collection("user_trackers");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Meal Reminder Fallback] Starting check");

    const now = new Date();
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[Meal Reminder Fallback] Total users to check: ${totalUsers}`);

    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Meal Reminder Fallback] Processing batch: ${users.length} users (${processedUsers + users.length}/${totalUsers} total)`
      );

      for (const user of users) {
        const userId = user._id.toHexString();

        // Skip reminders for very new accounts to avoid noisy first-day nudges.
        if (isWithinNewAccountGracePeriod(now, user)) {
          continue;
        }

        const mealPrefs = user.mealLoggingReminderPrefs;

        // Same two-collection "whichever is fresher" activity signal
        // checkMealLoggingInactivityReminders uses, reused as-is here.
        const latestProgress = await progressCollection
          .find({ userId: userId })
          .sort({ progressDate: -1 })
          .limit(1)
          .toArray();
        const latestTrackerUpdate = await trackersCollection
          .find({ userId: userId })
          .sort({ lastUpdated: -1 })
          .limit(1)
          .toArray();
        const latestActivityDate = resolveLatestActivityDate(
          latestProgress[0]?.progressDate,
          latestTrackerUpdate[0]?.lastUpdated
        );

        for (const meal of ["lunch", "dinner"]) {
          const decision = decideMealReminderFallback(
            meal,
            mealPrefs,
            now,
            latestActivityDate,
            user.timezoneOffsetMinutes
          );
          if (!decision) continue;

          const type = mealReminderFallbackType(meal);

          // One fallback notification per meal per user per local day --
          // lunch and dinner dedupe independently since they're distinct
          // `type` values, so a repeated scheduler run within the same
          // window (or later the same day) can't double-create either.
          const today = localDayStartUtc(now, user.timezoneOffsetMinutes);
          const existingToday = await findTodaysNotification(
            notificationsCollection,
            userId,
            type,
            today
          );
          if (existingToday) continue;

          await notificationsCollection.insertOne({
            userId: userId,
            type: type,
            title: decision.title,
            message: decision.message,
            createdAt: new Date(),
          });
          notificationsCreated++;
        }
      }

      processedUsers += users.length;

      if (users.length < BATCH_SIZE) {
        hasMore = false;
      }

      console.log(
        `[Meal Reminder Fallback] Batch complete. Progress: ${processedUsers}/${totalUsers} users processed, ${notificationsCreated} reminders created so far`
      );
    }

    console.log(
      `[Meal Reminder Fallback] Completed. Processed ${processedUsers} users, created ${notificationsCreated} reminders`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking meal reminder fallbacks:", error);
    throw new Error(`Meal reminder fallback check failed: ${error.message}`);
  }
}

/**
 * App-open inactivity reminders.
 *
 * NOT gated by any Notification Settings toggle: there is currently no
 * dedicated preference for "app inactivity" in the product (the Settings
 * page's four togglable types are Expiring Ingredients, Tracker Reminders,
 * Education, and Administrative Updates), and mapping it onto Tracker
 * Reminders would be an unreviewed product decision -- these two are
 * already distinct, separately-dedup'd notification types
 * (app_inactivity_reminder vs tracker_reminder). Left unchanged pending an
 * explicit product decision; see the notification-system implementation
 * notes for this open question.
 */
async function checkAppInactivityReminders() {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const notificationsCollection = db.collection("notifications");

    console.log("[App Inactivity Reminder] Starting check");

    const now = new Date();
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[App Inactivity Reminder] Total users to check: ${totalUsers}`);

    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      for (const user of users) {
        const userId = user._id.toHexString();

        // Skip reminders for very new accounts to avoid noisy first-day nudges.
        if (isWithinNewAccountGracePeriod(now, user)) {
          continue;
        }

        // Only one app inactivity reminder notification per user per local day.
        const today = localDayStartUtc(now, user.timezoneOffsetMinutes);
        const existingToday = await findTodaysNotification(
          notificationsCollection,
          userId,
          "app_inactivity_reminder",
          today
        );
        if (existingToday) continue;

        const rawLastActive = user.lastActiveAt || user.lastLoginAt || user.updatedAt;
        if (!rawLastActive) continue;

        const lastActiveDate = new Date(rawLastActive);
        if (Number.isNaN(lastActiveDate.getTime())) continue;

        const bucket = getInactivityBucket(
          now,
          lastActiveDate,
          APP_OPEN_DAY_MILESTONES,
          APP_OPEN_WEEK_MILESTONES,
          APP_OPEN_MONTH_MILESTONES,
          user.timezoneOffsetMinutes
        );

        if (!bucket) continue;

        const existing = await notificationsCollection.findOne({
          userId: userId,
          type: "app_inactivity_reminder",
          bucketKey: bucket.key,
        });

        if (existing) continue;

        await notificationsCollection.insertOne({
          userId: userId,
          type: "app_inactivity_reminder",
          title: "We miss you at MyFoodRx",
          message: formatMessageWithReason(
            "Open MyFoodRx to review your pantry, trackers and recommendations.",
            "you last opened MyFoodRx",
            bucket.key
          ),
          bucketKey: bucket.key,
          daysSinceLastActive: bucket.days,
          createdAt: new Date(),
        });

        notificationsCreated++;
      }

      processedUsers += users.length;
      if (users.length < BATCH_SIZE) hasMore = false;
    }

    console.log(
      `[App Inactivity Reminder] Completed. Processed ${processedUsers} users, created ${notificationsCreated} reminders`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking app inactivity reminders:", error);
    throw new Error(`App inactivity reminder check failed: ${error.message}`);
  }
}

async function runAllNotificationChecks() {
  const expiring = await checkExpiringIngredients();
  const expired = await checkExpiredItems();
  const meal = await checkMealLoggingInactivityReminders();
  const mealFallback = await checkMealReminderFallbacks();
  const app = await checkAppInactivityReminders();
  return {
    status: "success",
    expiringIngredients: expiring.notificationsCreated || 0,
    expiredItems: expired.notificationsCreated || 0,
    mealLoggingReminders: meal.notificationsCreated || 0,
    mealReminderFallbacks: mealFallback.notificationsCreated || 0,
    appInactivityReminders: app.notificationsCreated || 0,
  };
}

// Exposed only for the scripts/test_*.js regression checks so they exercise
// the real production logic instead of a reimplementation that could
// silently drift from it. Not used by the Cloud Function runtime itself,
// which only invokes exports.notificationScheduler.
exports.__testables = {
  localDayStartUtc,
  dayDiffFloor,
  addMonthsLocalDayStartUtc,
  getInactivityBucket,
  bucketLabel,
  formatMessageWithReason,
  formatTrackerInactivityBody,
  expiringSoonHeading,
  expiringItemsListSummary,
  decideExpiredItemsDigest,
  decideTrackerReminder,
  findTodaysNotification,
  resolveLatestActivityDate,
  isNotificationTypeEnabled,
  isWithinNewAccountGracePeriod,
  NOTIFICATION_TYPE_TO_PREF_KEY,
  isMealRemindersMasterEnabled,
  mealReminderOwnEnabled,
  isPersonalizedMealReminderEnabled,
  hasAnyPersonalizedMealReminderEnabled,
  decideMealReminderFallback,
  mealReminderFallbackType,
  localMinutesOfDay,
  MEAL_FALLBACK_TARGET_MINUTES,
  MEAL_LOG_WINDOW_MINUTES,
  MEAL_FALLBACK_COPY,
};
