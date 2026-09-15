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

    // expired_items also has a client-side check in SimpleNotificationService;
    // both share the pantry_items.expiredNotifiedAt ledger so neither
    // double-notifies about the same item.
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

// Local-time targets, in minutes since local midnight, for
// tracker_reminder, app_inactivity_reminder, expiring_ingredients, and
// expired_items. Floors, not fixed slots -- a sweep that runs late still
// fires once local time has passed the target, bounded by each check's
// own once-per-local-day dedupe.
const TRACKER_REMINDER_TARGET_MINUTES = 19 * 60; // 7:00 PM local
const APP_INACTIVITY_TARGET_MINUTES = 9 * 60; // 9:00 AM local
const EXPIRING_INGREDIENTS_TARGET_MINUTES = 8 * 60; // 8:00 AM local
const EXPIRED_ITEMS_TARGET_MINUTES = 8 * 60; // 8:00 AM local

// Fallback reminders for whichever of lunch/dinner the user hasn't
// personally enabled -- personalized breakfast/lunch/dinner reminders run
// entirely client-side (see notification_service.dart) and never reach
// this pipeline. No breakfast fallback exists. Each meal is evaluated
// independently; see decideMealReminderFallback().
//
// Target local times, in minutes since local midnight. A floor, not a
// fixed slot -- eligible for the rest of the day once local time passes it.
const MEAL_FALLBACK_TARGET_MINUTES = {
  lunch: 13 * 60 + 30, // 1:30 PM local
  dinner: 19 * 60 + 30, // 7:30 PM local
};

// Local-time windows used to approximate "was this meal already logged
// today." There's no meal-type field in the data model, so any tracker
// activity inside the window counts as logged -- the same approximation
// checkMealLoggingInactivityReminders relies on for its own signal.
const MEAL_LOG_WINDOW_MINUTES = {
  lunch: [12 * 60, 15 * 60 + 30], // 12:00 PM - 3:30 PM
  dinner: [17 * 60 + 30, 20 * 60], // 5:30 PM - 8:00 PM
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

// Number of local calendar-day boundaries crossed between `earlier` and
// `later` -- not elapsed 24-hour periods. Don't simplify to
// Math.floor((later - earlier) / DAY_MS); that reintroduces UTC-day bugs.
function dayDiffFloor(later, earlier, timezoneOffsetMinutes) {
  const msPerDay = 24 * 60 * 60 * 1000;
  const laterStart = localDayStartUtc(later, timezoneOffsetMinutes);
  const earlierStart = localDayStartUtc(earlier, timezoneOffsetMinutes);
  return Math.floor((laterStart.getTime() - earlierStart.getTime()) / msPerDay);
}

// Adds `months` to `date`'s local calendar day, clamping day-of-month
// overflow to the last day of the target month (Jan 31 + 1 month -> Feb
// 28/29, not Mar 3). Returns that day's local midnight, in UTC, so it can
// be compared against another localDayStartUtc() value.
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

// Leads with the call to action, then the "why" (time since sincePhrase)
// last, so it reads as personalized rather than a bare "It's been 1 day."
function formatMessageWithReason(callToAction, sincePhrase, bucketKey) {
  const label = bucketLabel(bucketKey);
  if (!label) return callToAction;
  return `${callToAction} It's been ${label} since ${sincePhrase}.`;
}

// Leads with the time-since clause instead of a call to action -- the
// opposite ordering from formatMessageWithReason, which App Inactivity
// uses instead.
function formatTrackerInactivityBody(bucketKey) {
  const label = bucketLabel(bucketKey);
  if (!label) return "Check in when you're ready.";
  return `It's been ${label} since you last logged a meal. Check in when you're ready.`;
}

// Decides which (if any) tracker reminder a user should get today.
//   1. The inactivity ladder takes priority over the same-day daily
//      reminder -- never send both.
//   2. The daily ("d0") reminder is suppressed when Meal Reminders are
//      enabled, since the user already gets their own nudge.
// Does not perform the once-per-bucket or once-per-local-day dedupe --
// callers must do that before inserting. Returns null if nothing to send.
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
    // Day 1 is covered by the user's own meal reminders; days 2-6, weekly
    // and monthly milestones still fire regardless -- ignoring reminders
    // that long is its own signal worth surfacing.
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

  // <= 0 means the latest activity's local day is today -- already
  // logged, so no daily reminder needed.
  const loggedToday =
    latestDate != null && dayDiffFloor(now, latestDate, timezoneOffsetMinutes) <= 0;
  if (loggedToday) return null;

  // A user with Meal Reminders enabled already gets their own nudge for
  // "haven't logged today" -- this daily reminder would be redundant.
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
// Keeps the today/tomorrow/N-days urgency signal in the heading; the body
// is fixed regardless of day count. Mirrors
// SimpleNotificationService.expiringItemHeading (Dart).
function expiringSoonHeading(itemName, daysUntilExpiry) {
  if (daysUntilExpiry <= 0) return `${itemName} expires today`;
  if (daysUntilExpiry === 1) return `${itemName} expires tomorrow`;
  return `${itemName} expires in ${daysUntilExpiry} days`;
}

// Truncates a multi-item digest body to the first 3 names plus an
// "and N more" tail. Mirrors SimpleNotificationService.expiringItemsListSummary (Dart).
function expiringItemsListSummary(names) {
  const maxNames = 3;
  const shown = names.slice(0, maxNames);
  const remaining = names.length - shown.length;
  return remaining > 0 ? `${shown.join(", ")} and ${remaining} more` : shown.join(", ");
}

// Decides the expired_items digest for a user, given the names/ids of
// their currently-expired items and which ids were already notified about
// (pantry_items.expiredNotifiedAt -- shared with the client-side path in
// backend/app/routers/notifications.py). `itemIds`/`alreadyNotifiedIds` are
// plain hex-string ids so this stays a pure, DB-free function.
//
// pushEligible=false means every expired item was already notified about
// before -- still create the Notification Center doc, but stamp it with
// sentAt immediately so it never gets pushed as a daily nag.
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
// equivalent map in notification-delivery/index.js. "app_inactivity_reminder"
// is deliberately absent -- there's no dedicated Settings toggle for it.
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
// / mealReminderOwnEnabled / isMealReminderEnabled. `enabled` at the top
// level is the master switch -- off means every meal is off regardless of
// its own flag. A meal with its own `enabled` key is authoritative once
// the master is on, even overriding a stale top-level `enabled: true`. An
// old-format doc with no per-meal key falls back to the top-level flag.
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

// Whether the user has a personalized reminder configured for at least
// one meal. The master switch can be on with every meal off (e.g. right
// after a reset, or before the user picks one), in which case nothing
// personalized fires -- using the bare master flag as the "meal reminders
// enabled" signal would wrongly suppress the tracker daily reminder too,
// leaving the user with no reminders at all.
function hasAnyPersonalizedMealReminderEnabled(prefs) {
  return ["breakfast", "lunch", "dinner"].some((meal) =>
    isPersonalizedMealReminderEnabled(prefs, meal)
  );
}

// Current UTC offset (minutes) for IANA zone `timeZoneId` at `nowUtc`,
// via Intl's built-in ICU timezone database -- correct across DST since
// the zone name doesn't change, only the offset it resolves to. Formats
// `nowUtc` in `timeZoneId`, reinterprets those wall-clock parts as UTC,
// and diffs against the real instant. Mirrors notification-delivery/index.js.
// Returns null for an unresolvable identifier; caller falls back to the
// stored numeric offset.
function getOffsetMinutesForZone(nowUtc, timeZoneId) {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timeZoneId,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
      .formatToParts(nowUtc)
      .reduce((acc, part) => {
        acc[part.type] = part.value;
        return acc;
      }, {});
    const asIfUtc = Date.UTC(
      parseInt(parts.year, 10),
      parseInt(parts.month, 10) - 1,
      parseInt(parts.day, 10),
      parseInt(parts.hour, 10) % 24,
      parseInt(parts.minute, 10),
      parseInt(parts.second, 10)
    );
    return Math.round((asIfUtc - nowUtc.getTime()) / 60000);
  } catch (err) {
    // Unresolvable IANA identifier -- never let bad timezone data crash
    // the sweep for every user behind it in the batch.
    return null;
  }
}

// Prefers the DST-correct offset derived from `user.timezoneId`; falls
// back to the stored `user.timezoneOffsetMinutes` (or 0/UTC) when the id
// is missing or unresolvable. decideMealReminderFallback still takes a
// raw offset parameter -- callers pass this function's result into it.
function effectiveOffsetMinutes(nowUtc, user) {
  const timeZoneId = user?.timezoneId;
  if (typeof timeZoneId === "string" && timeZoneId.length > 0) {
    const resolved = getOffsetMinutesForZone(nowUtc, timeZoneId);
    if (resolved !== null) return resolved;
  }
  const stored = user?.timezoneOffsetMinutes;
  return Number.isFinite(stored) ? stored : 0;
}

// Mirrors notification-delivery/index.js's localMinutesOfDay (same
// no-shared-package mirroring convention as every other timezone helper in
// this file).
function localMinutesOfDay(nowUtc, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  const local = new Date(nowUtc.getTime() + offsetMs);
  return local.getUTCHours() * 60 + local.getUTCMinutes();
}

// Decides whether a meal's generic fallback reminder should fire right
// now for one user. Pure, no DB access. Does not perform the
// once-per-local-day dedupe -- callers must run findTodaysNotification first.
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
// `sinceUtc`. `createdAt` may be a native BSON Date (written here) or an
// ISO string (written by the Python backend), so this converts before
// comparing -- a plain `{createdAt: {$gte: ...}}` filter would miss the
// other language's docs and let both paths create a same-day duplicate.
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

        const offsetMinutes = effectiveOffsetMinutes(now, user);

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
                dayDiffFloor(expiringItems[0].expiryDateParsed, now, offsetMinutes)
              )
            : `${names.length} items expire soon`;
        const message =
          names.length === 1
            ? "Check your pantry and use it before it expires."
            : `${expiringItemsListSummary(names)}. Check your pantry and use them before they expire.`;

        // If a digest exists today (in the user's local timezone), update it; otherwise insert new
        const today = localDayStartUtc(now, offsetMinutes);

        const existing = await findTodaysNotification(
          notificationsCollection,
          userId,
          "expiring_ingredient",
          today
        );

        if (existing) {
          // Already created today -- refresh the content regardless of
          // time-of-day; the floor below only gates first creation.
          await notificationsCollection.updateOne(
            { _id: existing._id },
            { $set: { title, message, updatedAt: new Date() } }
          );
          console.log(
            `[Expiring Ingredients] Updated digest for user ${userId} with ${names.length} items`
          );
        } else if (localMinutesOfDay(now, offsetMinutes) < EXPIRING_INGREDIENTS_TARGET_MINUTES) {
          // Not yet 8am local -- retried on a later sweep.
          continue;
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
 * Scheduled catch-all for expired pantry items, for users who haven't
 * opened the app since an item expired. Runs alongside the client-side
 * check in SimpleNotificationService.checkExpiredItems; both share the
 * pantry_items.expiredNotifiedAt ledger so neither double-notifies about
 * the same item. See decideExpiredItemsDigest() for the dedup rule.
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

        const offsetMinutes = effectiveOffsetMinutes(now, user);

        // One expired_items document per user per local day -- mirrors the
        // same per-day guard checkExpiringIngredients uses for its type.
        const today = localDayStartUtc(now, offsetMinutes);
        const existingToday = await findTodaysNotification(
          notificationsCollection,
          userId,
          "expired_items",
          today
        );
        if (existingToday) continue;

        // Not yet 8am local -- retried on a later sweep.
        if (localMinutesOfDay(now, offsetMinutes) < EXPIRED_ITEMS_TARGET_MINUTES) continue;

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

        const offsetMinutes = effectiveOffsetMinutes(now, user);

        // Only one tracker reminder notification per user per local day.
        const today = localDayStartUtc(now, offsetMinutes);
        const existingToday = await findTodaysNotification(
          notificationsCollection,
          userId,
          "tracker_reminder",
          today
        );
        if (existingToday) {
          continue;
        }

        // Not yet 7pm local -- retried on a later sweep. Gates both the
        // daily (d0) and inactivity-milestone reminders, since both come
        // from the same decideTrackerReminder() call below.
        if (localMinutesOfDay(now, offsetMinutes) < TRACKER_REMINDER_TARGET_MINUTES) {
          continue;
        }

        const latestProgress = await progressCollection
          .find({
            userId: userId,
          })
          .sort({ progressDate: -1 })
          .limit(1)
          .toArray();

        // tracker_progress only gets a row once a day, at reset -- always
        // ~1 day stale until then. user_trackers updates live on every log
        // (PATCH /trackers/{id}), so use whichever is more recent, or
        // every active user would trip the d1 bucket regardless of
        // same-day logging.
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
          offsetMinutes
        );
        if (!decision) {
          continue;
        }

        // Milestones fire at most once ever per user; the daily ("d0")
        // reminder is meant to recur, guarded only by the existingToday
        // check above (at most one tracker_reminder per local day).
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
 * Generic fallback meal reminders (lunch/dinner), evaluated independently
 * per meal. If the user has a personalized reminder for that meal, no
 * fallback fires -- their client-scheduled reminder already covers it.
 * Otherwise it's eligible once local time passes the meal's target and it
 * hasn't already been "logged" (see decideMealReminderFallback). No
 * breakfast fallback exists.
 *
 * Not gated by any Notification Settings toggle -- users control this
 * directly via the per-meal Meal Reminders switches.
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

        const offsetMinutes = effectiveOffsetMinutes(now, user);

        for (const meal of ["lunch", "dinner"]) {
          const decision = decideMealReminderFallback(
            meal,
            mealPrefs,
            now,
            latestActivityDate,
            offsetMinutes
          );
          if (!decision) continue;

          const type = mealReminderFallbackType(meal);

          // Lunch and dinner dedupe independently since they're distinct
          // `type` values -- one fallback per meal per user per local day.
          const today = localDayStartUtc(now, offsetMinutes);
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
 * Not gated by any Notification Settings toggle -- there's no dedicated
 * preference for it, and it's a distinct, separately-deduped type from
 * tracker_reminder.
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

        const offsetMinutes = effectiveOffsetMinutes(now, user);

        // Only one app inactivity reminder notification per user per local day.
        const today = localDayStartUtc(now, offsetMinutes);
        const existingToday = await findTodaysNotification(
          notificationsCollection,
          userId,
          "app_inactivity_reminder",
          today
        );
        if (existingToday) continue;

        // Not yet 9am local -- retried on a later sweep.
        if (localMinutesOfDay(now, offsetMinutes) < APP_INACTIVITY_TARGET_MINUTES) continue;

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
          offsetMinutes
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

// Exposed only for scripts/test_*.js so tests exercise the real logic
// instead of a reimplementation. Not used by the runtime itself.
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
  getOffsetMinutesForZone,
  effectiveOffsetMinutes,
  TRACKER_REMINDER_TARGET_MINUTES,
  APP_INACTIVITY_TARGET_MINUTES,
  EXPIRING_INGREDIENTS_TARGET_MINUTES,
  EXPIRED_ITEMS_TARGET_MINUTES,
};
