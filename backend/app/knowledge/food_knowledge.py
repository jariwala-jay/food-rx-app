"""
Food & Nutrition Knowledge Base for MyFoodRx RAG Chatbot.
Sources: CDC, AHA, ADA, USDA/MyPlate, NIH/NIDDK/NHLBI.
63 documents covering: Sleep, Exercise, Hydration, Hypertension,
Pre-Diabetes, Diabetes, Obesity, and General Nutrition.
"""

KNOWLEDGE_DOCS = [
    {
        "id": "sleep_basics",
        "title": "Sleep: How Much You Need and Why It Matters",
        "category": "Sleep",
        "tags": ["sleep", "sleep duration", "health", "chronic condition"],
        "source": "https://www.cdc.gov/sleep/about/index.html",
        "content": (
            "Adults aged 18 to 60 need at least 7 or more hours of sleep per night, according to the CDC. "
            "Adults aged 61 to 64 need 7 to 9 hours, and adults aged 65 and older need 7 to 8 hours. "
            "The National Sleep Foundation recommends 7 to 9 hours for adults generally. Teenagers aged 13 to "
            "18 need 8 to 10 hours. School-age children aged 6 to 12 need 9 to 12 hours. Preschoolers aged "
            "3 to 5 need 10 to 13 hours including naps. These are not occasional targets. Consistently getting "
            "the right amount of sleep every night is what produces lasting health benefits.\n\n"
            "Sleep is the time when the body repairs tissues, consolidates memories, regulates hormones, and "
            "supports immune function. Growth hormone, which plays a role in muscle repair and fat metabolism, "
            "is released primarily during deep sleep. The brain clears waste products during sleep through a "
            "process called the glymphatic system. Without adequate sleep, these essential maintenance processes "
            "are interrupted.\n\n"
            "Short sleep, defined as fewer than 7 hours per night for adults, is associated with significantly "
            "increased risk of obesity, type 2 diabetes, heart disease, high blood pressure, stroke, mental "
            "health disorders, and early death. Adults who sleep fewer than 6 hours per night are more than "
            "twice as likely to report obesity compared to those sleeping 7 to 9 hours. Poor sleep raises "
            "cortisol (the stress hormone), increases appetite, and specifically promotes cravings for "
            "high-calorie, high-carbohydrate foods. This triple effect makes weight management much harder for "
            "people who are not sleeping enough.\n\n"
            "Sleep quality matters as much as duration. Even 8 hours of fragmented or shallow sleep does not "
            "provide the same benefits as 8 hours of uninterrupted sleep. Signs of poor sleep quality include "
            "waking frequently during the night, feeling unrefreshed in the morning, needing an alarm clock to "
            "wake up every day, and feeling drowsy during the day. Sleep apnea, where breathing is repeatedly "
            "interrupted during sleep, is a major cause of poor sleep quality and is strongly linked to heart "
            "disease, high blood pressure, and type 2 diabetes.\n\n"
            "Daytime function is profoundly affected by sleep. Reaction time, decision-making, emotional "
            "regulation, and concentration all decline after poor sleep in ways comparable to being legally "
            "intoxicated. For people managing chronic health conditions like diabetes or hypertension, poor sleep "
            "directly worsens blood sugar regulation and raises blood pressure the following day."
        ),
    },
    {
        "id": "sleep_hygiene",
        "title": "Sleep Hygiene: Habits That Improve Sleep Quality",
        "category": "Sleep",
        "tags": ["sleep", "sleep habits", "routine", "sleep quality"],
        "source": "https://www.cdc.gov/sleep/about/index.html",
        "content": (
            "Sleep hygiene refers to a set of behaviors and environmental conditions that support "
            "consistently good sleep. Unlike medication, sleep hygiene habits work gradually but have lasting "
            "effects and no side effects. The most important habit is maintaining a consistent sleep schedule, "
            "which means going to bed and waking up at the same time every day including weekends. The body's "
            "internal clock, called the circadian rhythm, sets itself to this pattern. Irregular sleep timing "
            "is one of the most common causes of difficulty falling or staying asleep.\n\n"
            "Light is the most powerful signal for the circadian rhythm. Exposure to natural light in the "
            "morning, even 15 to 30 minutes outdoors, helps set the body clock for alertness during the day "
            "and sleepiness at night. Bright light in the evening, especially from phones, tablets, computers, "
            "and LED televisions, suppresses melatonin production and delays sleepiness. Reducing screen "
            "brightness and using blue-light-filtering settings after sunset significantly improves sleep onset "
            "time.\n\n"
            "The bedroom environment has a measurable impact on sleep quality. Cool temperatures between 60 and "
            "67 degrees Fahrenheit (15 to 19 degrees Celsius) are associated with the best sleep because the "
            "body naturally drops its core temperature during sleep. Darkness is important, as even small "
            "amounts of light can disrupt the sleep cycle. Noise is a significant disruptor. White noise "
            "machines or earplugs can help in noisy environments. The bed should be associated only with sleep. "
            "Working, scrolling through a phone, or watching TV in bed trains the brain to associate the bed "
            "with wakefulness.\n\n"
            "Caffeine has a half-life of approximately 5 to 6 hours, meaning that half of the caffeine in a "
            "2 PM coffee is still circulating at 8 PM. Caffeine consumed within 6 hours of bedtime measurably "
            "reduces total sleep time and deep sleep. Alcohol is commonly misunderstood as a sleep aid. While "
            "it does cause initial drowsiness, it fragments sleep in the second half of the night, suppresses "
            "deep sleep, and increases nighttime waking. Large meals within 2 to 3 hours of bedtime can also "
            "interfere with sleep, particularly in people prone to acid reflux.\n\n"
            "A wind-down routine in the 30 to 60 minutes before bed significantly improves sleep onset. This "
            "may include reading (not on a device), taking a warm bath or shower, light stretching, or "
            "relaxation breathing exercises. The warm bath works partly because the drop in body temperature "
            "afterward signals to the brain that it is time to sleep. Regular physical activity improves overall "
            "sleep quality, but vigorous exercise within 1 to 2 hours of bedtime can delay sleep in some people "
            "due to elevated heart rate and body temperature."
        ),
    },
    {
        "id": "sleep_and_diet",
        "title": "Sleep and Nutrition: How They Affect Each Other",
        "category": "Sleep",
        "tags": ["sleep", "nutrition", "blood sugar", "weight"],
        "source": "https://pmc.ncbi.nlm.nih.gov/articles/PMC5015038/",
        "content": (
            "Sleep and diet have a two-way relationship. What you eat affects how well you sleep, and how "
            "well you sleep affects what and how much you eat. Understanding this connection is important for "
            "anyone trying to manage weight, blood sugar, or blood pressure through lifestyle changes.\n\n"
            "Poor sleep disrupts two key hunger hormones: ghrelin and leptin. Ghrelin signals hunger and "
            "leptin signals fullness. After insufficient sleep, ghrelin levels rise and leptin levels fall. "
            "This means people feel hungrier than usual and have a weaker sense of fullness after eating. "
            "Studies show that sleep-deprived adults consume on average 300 to 400 extra calories per day "
            "compared to well-rested adults. The extra calories come predominantly from snack foods, processed "
            "foods, and sweets.\n\n"
            "Sleep deprivation impairs insulin sensitivity in a manner similar to pre-diabetes. Even one week "
            "of sleeping 5 to 6 hours per night measurably raises fasting blood sugar and reduces the body's "
            "response to insulin. For people who already have pre-diabetes or type 2 diabetes, consistently poor "
            "sleep significantly worsens blood glucose control and may require medication adjustments. The "
            "mechanism involves elevated cortisol and growth hormone imbalances that interfere with how cells "
            "take up glucose.\n\n"
            "Certain nutrients support sleep quality. Tryptophan is an amino acid found in turkey, chicken, "
            "eggs, cheese, nuts, and seeds. It is a precursor to serotonin and melatonin, both of which regulate "
            "sleep. Magnesium is found in dark leafy greens, nuts, seeds, and whole grains. It has a calming "
            "effect on the nervous system and is associated with better sleep quality. Low magnesium levels are "
            "linked to insomnia and restless sleep. Complex carbohydrates consumed in the evening, such as "
            "oatmeal, sweet potatoes, or whole grain bread, can promote serotonin production and facilitate sleep "
            "onset. High-sugar or high-fat meals before bed tend to fragment sleep.\n\n"
            "Melatonin is the hormone that signals nighttime to the body. It is found in small amounts in "
            "certain foods including tart cherry juice, grapes, tomatoes, and walnuts. Tart cherry juice has "
            "been studied in small trials and shown modest improvements in sleep duration and quality. While "
            "food-based melatonin levels are much lower than those in supplements, including these foods as part "
            "of an evening routine may provide a gentle supporting effect alongside good sleep hygiene practices."
        ),
    },
    {
        "id": "sleep_conditions",
        "title": "Sleep Problems Linked to Chronic Health Conditions",
        "category": "Sleep",
        "tags": ["sleep", "sleep disorders", "diabetes", "hypertension"],
        "source": "https://www.nhlbi.nih.gov/health/sleep-apnea, https://www.nhlbi.nih.gov/science/sleep-science-and-sleep-disorders",
        "content": (
            "Several common chronic health conditions are closely linked to sleep disorders, and the "
            "relationship runs in both directions. The health condition worsens sleep, and poor sleep worsens "
            "the health condition. Understanding these connections helps explain why improving sleep is an "
            "important part of managing conditions like hypertension, diabetes, and obesity.\n\n"
            "Obstructive sleep apnea (OSA) is the most common sleep disorder associated with chronic disease. "
            "In OSA, the muscles of the throat relax during sleep, blocking the airway and causing repeated "
            "pauses in breathing, sometimes hundreds of times per night. Each episode causes a brief arousal "
            "and a spike in blood pressure and heart rate. Obesity is a major risk factor for OSA because "
            "excess tissue around the throat narrows the airway. OSA dramatically raises the risk of high blood "
            "pressure, atrial fibrillation, heart attack, stroke, and type 2 diabetes. Treatment with a CPAP "
            "machine, which keeps the airway open with a continuous stream of air, significantly lowers blood "
            "pressure and improves glucose control in people with OSA.\n\n"
            "High blood pressure and sleep have a complicated relationship. Normal blood pressure dips by 10 to "
            "20 percent during sleep. This is called nocturnal dipping, and its absence is a marker for "
            "cardiovascular risk. People with OSA or fragmented sleep often lose this nighttime dip, keeping "
            "their cardiovascular system under continuous stress. Short sleep duration independently raises blood "
            "pressure, and the effect is dose-dependent. Shorter sleep equals higher blood pressure.\n\n"
            "Type 2 diabetes and sleep disorders frequently co-exist. Up to 70 percent of people with type 2 "
            "diabetes report poor sleep quality. High blood sugar during the night causes increased urination, "
            "which disrupts sleep. Neuropathy, which is nerve damage caused by diabetes, can cause restless leg "
            "syndrome and painful sensations that prevent deep sleep. Poor sleep also worsens insulin resistance "
            "and makes blood sugar harder to control the following day. Addressing sleep quality is now "
            "recognized as a meaningful component of diabetes management.\n\n"
            "Depression and anxiety frequently accompany chronic health conditions and have profound effects on "
            "sleep. Both cause hyperarousal of the nervous system, making it difficult to fall and stay asleep. "
            "Chronic sleep deprivation also increases the risk of developing depression and anxiety. People "
            "managing multiple health conditions should be aware that mood disorders may require separate "
            "assessment and support, including counseling or cognitive behavioral therapy for insomnia (CBT-I). "
            "CBT-I is now recognized as the most effective long-term treatment for chronic insomnia."
        ),
    },
    {
        "id": "sleep_recommendations_conditions",
        "title": "Sleep Goals by Health Condition",
        "category": "Sleep",
        "tags": ["sleep", "recommendations", "diabetes", "hypertension"],
        "source": "https://www.cdc.gov/heart-disease/about/sleep-and-heart-health.html",
        "content": (
            "Sleep recommendations are universal at 7 to 9 hours per night for adults, but certain health "
            "conditions make meeting these targets more urgent and require specific additional strategies.\n\n"
            "For people with hypertension, consistently sleeping 7 or more hours per night is associated with "
            "lower average blood pressure and better response to blood pressure medication. Sleep restriction "
            "studies show that even a few nights of sleeping fewer than 6 hours raises systolic blood pressure "
            "by 5 to 10 mmHg. Nighttime blood pressure monitoring is recommended for people with hypertension "
            "who also report poor sleep or snoring, as these may indicate sleep apnea. Eliminating alcohol is "
            "particularly important for this group because alcohol fragments sleep and raises nighttime blood "
            "pressure.\n\n"
            "For people with pre-diabetes or type 2 diabetes, sleep quality directly affects fasting blood sugar "
            "the following morning. Short sleep duration of fewer than 6 hours raises fasting glucose by an "
            "average of 10 to 14 mg/dL in people with diabetes, which is a clinically meaningful increase. Going "
            "to bed and waking at consistent times helps regulate cortisol, which is a key driver of morning "
            "blood sugar elevations known as the dawn phenomenon. People with diabetes should mention persistent "
            "sleep problems to their healthcare provider, as treatment of underlying sleep apnea often produces "
            "meaningful improvements in HbA1c.\n\n"
            "For people managing obesity, sleep is a direct factor in weight management. Sleeping fewer than "
            "7 hours reduces levels of leptin (the satiety hormone) and increases ghrelin (the hunger hormone). "
            "It also specifically increases appetite for calorie-dense foods. Several large studies have found "
            "that short sleepers regain weight more quickly after intentional weight loss compared to adequate "
            "sleepers. Aiming for consistent 7 to 9 hours of sleep should be considered a core component of any "
            "weight management plan, alongside dietary changes and physical activity.\n\n"
            "For general wellbeing and chronic disease prevention, the following sleep habits are recommended: "
            "establishing a consistent bedtime and wake time, keeping the bedroom dark and cool, limiting "
            "caffeine after noon, avoiding alcohol within 3 hours of bedtime, reducing screen use in the hour "
            "before bed, and incorporating a relaxing pre-sleep routine. If sleep problems persist for more than "
            "3 months despite good sleep hygiene, this qualifies as chronic insomnia and warrants evaluation by a "
            "healthcare provider. Cognitive behavioral therapy for insomnia (CBT-I) is more effective than "
            "sleeping pills for long-term insomnia management."
        ),
    },
    {
        "id": "exercise_guidelines_adults",
        "title": "Physical Activity Guidelines for Adults",
        "category": "Exercise",
        "tags": ["exercise", "guidelines", "fitness", "health"],
        "source": "https://www.cdc.gov/physical-activity-basics/adding-adults/what-counts.html",
        "content": (
            "The U.S. Physical Activity Guidelines for Americans recommend that adults get at least "
            "150 minutes of moderate-intensity aerobic activity per week, or at least 75 minutes of "
            "vigorous-intensity aerobic activity per week, or an equivalent combination of both. Adults "
            "should also perform muscle-strengthening activities on two or more days per week, working all "
            "major muscle groups. These are minimum targets. More physical activity provides additional "
            "health benefits.\n\n"
            "Moderate-intensity activities are those that raise heart rate and cause some breathlessness but "
            "still allow a conversation. Examples include brisk walking at 3 to 4 mph, cycling on flat "
            "terrain, water aerobics, dancing, gardening, and doubles tennis. Vigorous-intensity activities "
            "cause rapid breathing and make it difficult to say more than a few words without pausing. "
            "Examples include jogging or running, swimming laps, cycling fast or uphill, aerobics classes, "
            "and singles tennis.\n\n"
            "The 150-minute guideline does not need to be achieved in long sessions. Activity can be "
            "accumulated throughout the day in bouts as short as 10 minutes. Three 10-minute brisk walks in "
            "a day provide meaningful cardiovascular benefit and count toward the weekly total. For people "
            "who are very inactive, even small amounts of activity such as 10 to 20 minutes of walking per "
            "day produce significant health improvements compared to remaining sedentary. Some activity is "
            "always better than none.\n\n"
            "For additional health benefits, adults are encouraged to increase aerobic activity to 300 "
            "minutes per week at moderate intensity, or 150 minutes at vigorous intensity. Higher levels of "
            "activity are associated with even lower risks of heart disease, type 2 diabetes, several "
            "cancers, and early death. Adults who were previously sedentary should increase activity "
            "gradually by adding 5 to 10 minutes per week to reduce injury risk and build sustainable habits.\n\n"
            "Sedentary time, which is sitting or reclining for extended periods while awake, is independently "
            "harmful even for people who meet exercise guidelines at other times of day. Long periods of "
            "sitting slow metabolism, impair blood sugar regulation, and increase cardiovascular risk. "
            "Breaking up sitting time every 30 to 60 minutes with short bouts of standing or light movement, "
            "such as a 2-minute walk or light stretching, significantly reduces these risks. People with desk "
            "jobs or limited mobility should prioritize interrupting sitting time throughout the day."
        ),
    },
    {
        "id": "exercise_aerobic_types",
        "title": "Types of Aerobic Exercise and Their Benefits",
        "category": "Exercise",
        "tags": ["exercise", "cardio", "heart health", "fitness"],
        "source": "https://www.cdc.gov/physical-activity/php/guidelines-recommendations/",
        "content": (
            "Aerobic exercise, also called cardio, uses large muscle groups in continuous rhythmic movements "
            "that increase breathing and heart rate. Regular aerobic exercise strengthens the heart muscle, "
            "lowers resting heart rate, reduces blood pressure, improves cholesterol levels, and helps regulate "
            "blood sugar. It is one of the most powerful interventions available for preventing and managing "
            "hypertension, type 2 diabetes, and cardiovascular disease.\n\n"
            "Walking is the most accessible aerobic exercise and is appropriate for nearly all fitness levels, "
            "including people who are completely sedentary or managing multiple health conditions. Brisk "
            "walking, defined as walking at a pace that raises your heart rate and causes light breathlessness, "
            "provides the same cardiovascular benefits per minute as more intense activities when done "
            "consistently. A goal of 30 minutes of brisk walking most days of the week is a practical and "
            "achievable target for most people.\n\n"
            "Swimming and water-based exercises are excellent options for people with joint pain, arthritis, "
            "obesity, or mobility limitations. Water supports body weight, reducing impact on joints while "
            "still providing significant cardiovascular and muscular benefits. Water aerobics classes are widely "
            "available and appropriate for people of all fitness levels and ages. Swimming laps is a "
            "vigorous-intensity activity. Water walking and water aerobics are moderate-intensity activities.\n\n"
            "Cycling, both outdoors and on a stationary bike, is a low-impact moderate to vigorous activity "
            "depending on terrain and effort level. Stationary bikes are particularly useful for people with "
            "balance concerns. Cycling for 30 minutes at moderate effort burns approximately 200 to 300 "
            "calories, depending on body weight and intensity. For people with knee problems, cycling is often "
            "better tolerated than walking or jogging because it minimizes impact while still strengthening the "
            "quadriceps.\n\n"
            "Dancing, gardening, household chores, and recreational activities such as walking a golf course, "
            "bowling, and casual sports all count as physical activity and contribute to the weekly total. "
            "These activities are often more sustainable than formal exercise programs because they are "
            "enjoyable and embedded in daily life. Studies consistently find that people who find their "
            "physical activity enjoyable maintain it far longer than people who exercise primarily out of "
            "obligation."
        ),
    },
    {
        "id": "exercise_strength_training",
        "title": "Strength Training: Why It Matters for Health",
        "category": "Exercise",
        "tags": ["exercise", "strength training", "muscle", "metabolism"],
        "source": "https://www.cdc.gov/physical-activity-basics/guidelines/adults.html",
        "content": (
            "Strength training, also called resistance training or weight training, involves using resistance "
            "such as body weight, dumbbells, resistance bands, or gym machines to make muscles work against a "
            "force. The physical activity guidelines recommend strength training on at least 2 days per week "
            "for all adults, covering all major muscle groups: legs, hips, back, abdomen, chest, shoulders, "
            "and arms. Despite this recommendation, only about 30 percent of American adults currently meet the "
            "strength training guideline.\n\n"
            "Muscle tissue is metabolically active, meaning it burns calories even at rest. Building and "
            "maintaining muscle mass increases resting metabolic rate, which is the number of calories the body "
            "burns in a day without exercise. This is why strength training is an important component of weight "
            "management, particularly for preventing the metabolic slowdown that often accompanies aging. Adults "
            "naturally lose 3 to 8 percent of muscle mass per decade after age 30 if they do not actively "
            "maintain it through resistance exercise.\n\n"
            "For blood sugar regulation, strength training is highly effective. Muscle contractions during "
            "resistance exercise cause cells to take up glucose from the bloodstream independent of insulin. "
            "After a strength training session, muscle cells remain more sensitive to insulin for 24 to 48 "
            "hours, resulting in improved blood sugar control. The American Diabetes Association recommends that "
            "people with type 2 diabetes include both aerobic and resistance training in their exercise routine "
            "because the combination is more effective for HbA1c reduction than either type alone.\n\n"
            "For blood pressure, strength training provides a modest but meaningful reduction of approximately "
            "3 to 4 mmHg in systolic blood pressure with regular training. The key is to avoid holding the "
            "breath during heavy lifts, which causes a sharp temporary spike in blood pressure. Light to "
            "moderate resistance with controlled breathing is appropriate for people with hypertension. Isometric "
            "exercises such as holding a wall sit position have been shown in recent research to lower blood "
            "pressure particularly effectively.\n\n"
            "For people new to strength training, bodyweight exercises are an excellent starting point requiring "
            "no equipment: squats, lunges, push-ups (modified on knees if needed), calf raises, and seated or "
            "standing leg lifts. Resistance bands are inexpensive, portable, and joint-friendly. If using "
            "weights, starting light and focusing on proper form before increasing weight is essential to "
            "prevent injury. Performing 8 to 12 repetitions to moderate fatigue is an effective range for most "
            "health goals. Resting at least one day between strength sessions for the same muscle group allows "
            "recovery."
        ),
    },
    {
        "id": "exercise_for_hypertension",
        "title": "Exercise and High Blood Pressure Management",
        "category": "Exercise",
        "tags": ["exercise", "hypertension", "blood pressure", "management"],
        "source": "https://www.heart.org/en/health-topics/high-blood-pressure/changes-you-can-make-to-manage-high-blood-pressure/getting-active-to-control-high-blood-pressure",
        "content": (
            "Regular physical activity is one of the most effective non-drug interventions for lowering blood "
            "pressure. Aerobic exercise reduces systolic blood pressure (the top number) by an average of 5 to "
            "8 mmHg and diastolic blood pressure (the bottom number) by 3 to 5 mmHg in people with "
            "hypertension. For context, a 5 mmHg reduction in systolic pressure reduces the risk of stroke by "
            "approximately 14 percent and coronary heart disease by 9 percent. These effects are seen within a "
            "few weeks of starting a regular exercise program.\n\n"
            "The recommended starting point for people with hypertension is 30 minutes of moderate aerobic "
            "activity on most days of the week, totaling at least 150 minutes per week. Suitable activities "
            "include brisk walking, cycling, and swimming. Even 10-minute bouts of walking three times a day "
            "produce measurable blood pressure benefits. Consistency throughout the week is more important than "
            "intensity.\n\n"
            "Resistance training at moderate intensity with controlled breathing also reduces blood pressure by "
            "approximately 2 to 3 mmHg. Circuit training, which involves moving quickly between resistance "
            "exercises with minimal rest, provides both strength and cardiovascular benefits and is an efficient "
            "option. Isometric exercises such as wall squats and handgrip exercises have been shown in recent "
            "randomized controlled trials to reduce systolic blood pressure by 8 to 10 mmHg, making them "
            "surprisingly effective for hypertension management.\n\n"
            "Blood pressure typically drops for 4 to 12 hours after an aerobic exercise session. This is called "
            "post-exercise hypotension. People who exercise regularly keep their blood pressure lower throughout "
            "the day compared to inactive people. Light to moderate daily activity provides more continuous "
            "blood pressure control than occasional intense exercise sessions separated by days of inactivity.\n\n"
            "People with high blood pressure who are beginning an exercise program should check with their "
            "healthcare provider if their blood pressure is not well-controlled (above 180/110 mmHg), if they "
            "have other cardiovascular conditions, or if they experience dizziness, chest discomfort, or unusual "
            "breathlessness during activity. Starting with light to moderate intensity and gradually building up "
            "over several weeks is appropriate and safe for most people with hypertension."
        ),
    },
    {
        "id": "exercise_for_diabetes",
        "title": "Exercise and Blood Sugar Management",
        "category": "Exercise",
        "tags": ["exercise", "diabetes", "blood sugar", "insulin"],
        "source": "https://diabetes.org/health-wellness/fitness/weekly-exercise-targets",
        "content": (
            "Exercise is one of the most powerful tools for managing blood sugar. During aerobic exercise, "
            "muscles contract and take up glucose from the blood directly without requiring insulin. This means "
            "blood glucose typically falls during and immediately after aerobic activity. For people with type 2 "
            "diabetes or pre-diabetes, this effect is clinically meaningful and occurs within a single session.\n\n"
            "The American Diabetes Association recommends that people with type 2 diabetes aim for at least 150 "
            "minutes of moderate to vigorous aerobic activity per week, spread across at least 3 days, with no "
            "more than 2 consecutive days without activity. The 2-day gap limit is important because the blood "
            "sugar-lowering effects of a single exercise session last approximately 24 to 48 hours. After that "
            "window, insulin sensitivity returns toward baseline. Consistency throughout the week is therefore "
            "more important than longer but less frequent sessions.\n\n"
            "Resistance training is equally important for diabetes management. Regular strength training reduces "
            "HbA1c (the 3-month average blood glucose measure) by approximately 0.5 to 0.8 percent, which is a "
            "clinically meaningful improvement comparable to adding a low-dose glucose-lowering medication. "
            "Combining aerobic and resistance training produces greater reductions in HbA1c than either type "
            "alone.\n\n"
            "For people with type 1 diabetes and those taking insulin or sulfonylurea medications, exercise can "
            "cause blood sugar to drop too low during or up to several hours after activity. Checking blood "
            "sugar before exercise is recommended. If pre-exercise blood sugar is below 100 mg/dL, a small "
            "carbohydrate snack of about 15 grams, such as a banana or crackers, is advisable before moderate "
            "activity. People on type 2 diabetes medications that do not cause hypoglycemia, such as metformin, "
            "do not need to take these precautions.\n\n"
            "Breaking up sedentary time with activity interruptions, even 3-minute walks or light movement every "
            "30 minutes, significantly reduces post-meal blood sugar spikes compared to sitting continuously. "
            "This finding from controlled studies suggests that regular small movement breaks throughout the day "
            "are a complementary strategy to structured exercise sessions for diabetes management."
        ),
    },
    {
        "id": "exercise_for_weight_management",
        "title": "Exercise for Weight Management and Obesity",
        "category": "Exercise",
        "tags": ["exercise", "weight loss", "obesity", "calories"],
        "source": "https://www.cdc.gov/physical-activity-basics/guidelines/adults.html, https://www.niddk.nih.gov/health-information/weight-management/adult-overweight-obesity/eating-physical-activity",
        "content": (
            "Physical activity plays multiple roles in weight management. It burns calories, builds metabolically "
            "active muscle, reduces appetite hormones with moderate aerobic activity, improves mood, and "
            "prevents the metabolic slowdown associated with calorie restriction. Exercise alone without dietary "
            "changes produces modest weight loss for most people. The combination of dietary change plus regular "
            "exercise is consistently more effective than either approach alone.\n\n"
            "For significant weight loss, higher volumes of exercise are needed than the minimum guidelines for "
            "general health. Research and clinical guidelines suggest that 200 to 300 minutes of "
            "moderate-intensity aerobic activity per week produces meaningful weight loss when combined with "
            "dietary changes. For weight loss maintenance after achieving a goal, studies consistently find that "
            "people who successfully maintain weight loss long-term engage in 60 to 90 minutes per day of "
            "moderate-intensity activity.\n\n"
            "Aerobic exercise is most effective for burning calories during the session itself, while strength "
            "training builds muscle that raises the resting metabolic rate, increasing calories burned throughout "
            "the day. A combined program of aerobic exercise 4 to 5 days per week plus strength training 2 to 3 "
            "days per week is optimal for weight management. As weight is lost, aerobic capacity typically "
            "improves, making it possible to sustain longer or more intense sessions over time.\n\n"
            "For people with obesity who find vigorous exercise difficult or painful due to joint problems or "
            "breathlessness, starting with low-impact activities is appropriate and effective. Water exercises, "
            "cycling, chair exercises, yoga, and Tai Chi are accessible starting points that provide real "
            "benefits. The priority is reducing sedentary time and moving more throughout the day. Any upward "
            "change in activity level produces benefits, and intensity and duration can be gradually increased as "
            "fitness improves.\n\n"
            "Non-exercise activity thermogenesis (NEAT) refers to the calories burned through everyday activities "
            "like standing, fidgeting, walking to the mailbox, taking stairs, or parking further away. NEAT can "
            "account for 200 to 400 additional calories burned per day compared to sedentary habits. Simple "
            "strategies to increase NEAT include using a standing desk, taking calls while walking, taking "
            "stairs instead of elevators, and performing household tasks more actively. These small changes "
            "compound over time and are highly sustainable because they require no dedicated exercise time."
        ),
    },
    {
        "id": "exercise_safety_precautions",
        "title": "Exercising Safely: Precautions for Chronic Conditions",
        "category": "Exercise",
        "tags": ["exercise", "safety", "chronic conditions", "injury prevention"],
        "source": "https://diabetes.org/health-wellness/fitness/getting-started-safely, https://diabetes.org/health-wellness/fitness",
        "content": (
            "Most people with chronic health conditions including hypertension, type 2 diabetes, pre-diabetes, "
            "and obesity can safely exercise at moderate intensity without medical clearance, particularly if "
            "starting gradually. However, several situations warrant checking with a healthcare provider before "
            "beginning or significantly increasing exercise. These include uncontrolled high blood pressure above "
            "180/110 mmHg, recent heart attack or cardiac procedure, chest pain or pressure during activity, "
            "severe shortness of breath with minimal exertion, uncontrolled diabetes with very high blood "
            "sugars, and active foot ulcers or severe peripheral neuropathy in people with diabetes.\n\n"
            "A 5 to 10 minute warm-up of light activity before the main exercise session gradually increases "
            "blood flow to muscles and reduces the risk of muscle strains and cardiovascular stress. Examples "
            "include slow walking before brisk walking or gentle arm circles before swimming. A cool-down of 5 "
            "to 10 minutes of decreasing-intensity activity and gentle stretching helps blood pressure return to "
            "normal gradually and prevents dizziness on stopping.\n\n"
            "Staying well-hydrated during exercise is important. Dehydration reduces exercise performance, raises "
            "body temperature, and increases cardiovascular strain. A general guideline is to drink about 1 to 2 "
            "cups of water in the hour before exercise, drink regularly during exercise every 15 to 20 minutes, "
            "and rehydrate after exercise. Thirst is not a reliable early indicator of dehydration. By the time "
            "thirst is felt, mild dehydration has already occurred. Water is adequate for most moderate exercise "
            "sessions lasting under an hour.\n\n"
            "Muscle soreness 24 to 48 hours after an unfamiliar exercise (delayed onset muscle soreness) is "
            "normal and not a reason to stop exercising. It typically resolves within a few days and diminishes "
            "with consistent training. However, sharp or sudden pain during exercise, joint pain, chest pain or "
            "pressure, severe breathlessness, lightheadedness, or pain that persists beyond 72 hours warrants "
            "stopping exercise and seeking medical advice.\n\n"
            "Foot care is particularly important for people with diabetes who are beginning a walking or exercise "
            "program. Neuropathy may reduce sensation in the feet, making it difficult to feel blisters or "
            "injuries. Inspecting feet before and after exercise, wearing well-fitting athletic shoes with "
            "cushioning, wearing moisture-wicking socks, and avoiding barefoot exercise are essential "
            "precautions. Any sore, blister, cut, or redness that does not improve within 24 hours should be "
            "assessed by a healthcare provider, as foot wounds in people with diabetes can become serious "
            "quickly."
        ),
    },
    {
        "id": "hydration_basics",
        "title": "Hydration: How Much Water You Need and Why",
        "category": "Hydration",
        "tags": ["hydration", "water", "daily intake", "health"],
        "source": "https://www.cdc.gov/healthy-weight-growth/water-healthy-drinks/index.html",
        "content": (
            "Water makes up approximately 60 percent of the adult human body and is essential for virtually "
            "every bodily function. It transports nutrients and oxygen, regulates body temperature through "
            "sweating, lubricates joints, flushes waste products through the kidneys, and supports digestion. "
            "Even mild dehydration of just 1 to 2 percent of body water measurably impairs physical and "
            "cognitive performance.\n\n"
            "The National Academies of Sciences recommend a total daily water intake of approximately 3.7 "
            "liters (about 13 cups) for adult men and 2.7 liters (about 9 cups) for adult women. These totals "
            "include all water sources: drinking water, other beverages, and the water content of food. About "
            "20 percent of daily water intake typically comes from food, particularly fruits and vegetables. The "
            "commonly cited guideline of 8 glasses per day (8 ounces each, about 2 liters) is a reasonable "
            "general target, though individual needs vary considerably.\n\n"
            "Individual water needs increase with physical activity, hot or humid weather, high altitude, fever "
            "or illness, pregnancy, and breastfeeding. People with larger body size generally need more water. "
            "A practical way to assess hydration is urine color. Pale yellow indicates adequate hydration. Dark "
            "yellow or amber suggests insufficient water intake. Unusual thirst combined with frequent urination "
            "can be a sign of poorly controlled blood sugar and should be discussed with a healthcare provider.\n\n"
            "Plain water is the best choice for hydration. Beverages that count toward hydration include herbal "
            "teas, low-fat milk, and small amounts of 100% fruit juice. Coffee and caffeinated tea have a mild "
            "diuretic effect but still contribute to overall fluid intake. Alcohol is dehydrating. It suppresses "
            "the hormone that signals the kidneys to retain water, resulting in increased urination and net "
            "fluid loss. Sugary drinks such as sodas, sweetened juices, and energy drinks are not recommended "
            "as primary hydration sources because they contribute significant added sugar and calories with no "
            "additional nutritional benefit.\n\n"
            "Foods contribute meaningfully to hydration. Cucumber is 96 percent water, celery 95 percent, "
            "lettuce 94 percent, watermelon 92 percent, strawberries 91 percent, oranges 87 percent, and grapes "
            "81 percent. Including these in meals and snacks not only supports hydration but also provides "
            "fiber, vitamins, and minerals. For people who struggle to drink enough plain water, consuming more "
            "water-rich foods and adding slices of lemon, cucumber, or fresh mint to water can help increase "
            "total fluid intake."
        ),
    },
    {
        "id": "hydration_chronic_conditions",
        "title": "Hydration and Chronic Health Conditions",
        "category": "Hydration",
        "tags": ["hydration", "diabetes", "hypertension"],
        "source": "https://www.cdc.gov/healthy-weight-growth/water-healthy-drinks/index.html",
        "content": (
            "Adequate hydration is important for everyone, but it plays a particularly critical role in the "
            "management of several chronic health conditions. For some conditions, drinking enough water is "
            "genuinely therapeutic. For others, fluid needs require more careful management to avoid "
            "complications.\n\n"
            "For people with type 2 diabetes or high blood sugar, hydration is directly linked to blood glucose "
            "levels. When blood sugar is elevated, the kidneys work to remove the excess glucose through urine, "
            "and this process requires significant amounts of water. This is why excessive thirst and frequent "
            "urination are classic symptoms of uncontrolled diabetes. Staying well-hydrated supports this process "
            "and can help dilute blood glucose modestly. Choosing plain water over sugary drinks is essential, "
            "as sugar-sweetened beverages directly raise blood sugar and should be avoided by people with "
            "diabetes or pre-diabetes.\n\n"
            "For people with hypertension, adequate hydration supports kidney function and blood volume "
            "regulation. Mild chronic dehydration can cause the body to retain sodium and increase blood "
            "pressure. Staying hydrated with water rather than high-sodium drinks supports healthy blood "
            "pressure. However, people with heart failure or certain kidney diseases may need to limit fluid "
            "intake, as their bodies cannot manage excess fluid. These individuals should follow specific "
            "guidance from their healthcare team regarding daily fluid limits.\n\n"
            "For kidney health and urinary tract health, adequate water intake is the most important modifiable "
            "factor. Drinking enough water dilutes the urine, reduces the concentration of minerals that can "
            "form kidney stones, and flushes bacteria from the urinary tract, reducing infection risk. People "
            "who have had kidney stones are advised to drink enough water to produce at least 2 to 2.5 liters "
            "of urine per day.\n\n"
            "For people managing obesity, drinking water before meals is a practical weight management strategy. "
            "Studies show that drinking about 2 cups (500 ml) of water 30 minutes before a meal reduces calorie "
            "intake at that meal by approximately 13 to 22 percent in middle-aged and older adults. Replacing "
            "caloric beverages such as sodas, juices, and alcohol with water eliminates a significant source of "
            "empty calories. Sparkling water and unsweetened flavored water can serve as satisfying low-calorie "
            "alternatives for people who find plain water unappealing."
        ),
    },
    {
        "id": "hydration_beverages_guide",
        "title": "Choosing Healthy Beverages",
        "category": "Hydration",
        "tags": ["hydration", "beverages", "sugar", "diet"],
        "source": "https://www.cdc.gov/healthy-weight-growth/rethink-your-drink/",
        "content": (
            "Not all beverages are equal in their effects on health. Making informed choices about what to "
            "drink is as important as making informed choices about what to eat, particularly for people "
            "managing blood sugar, blood pressure, or body weight.\n\n"
            "Water is the ideal beverage for most people most of the time. It has no calories, no sugar, and no "
            "sodium. Sparkling water that is unflavored or has natural fruit essence added without sugar is an "
            "acceptable alternative. Infusing water with slices of citrus, cucumber, mint, or berries adds "
            "flavor without adding significant calories or sugar. Tap water in the United States is safe to "
            "drink in most areas and is significantly cheaper and more environmentally sustainable than bottled "
            "water.\n\n"
            "Coffee and tea without added sugar or high-calorie creamers are low-calorie beverages with "
            "potential health benefits. Both are associated with reduced risk of type 2 diabetes in large "
            "population studies. Green tea contains antioxidants called catechins that are associated with "
            "cardiovascular benefits. For people with hypertension, moderate caffeine intake of 2 to 3 cups of "
            "coffee per day does not significantly worsen blood pressure in habitual coffee drinkers, though "
            "those sensitive to caffeine may notice short-term increases.\n\n"
            "Low-fat (1%) or fat-free milk is the recommended dairy beverage for adults. Unsweetened almond "
            "milk, soy milk, oat milk, and other plant milks are lower in calories and suitable for people who "
            "are lactose intolerant or prefer dairy-free options. Checking labels is important because some "
            "plant milks contain significant added sugar or are very low in protein. Soy milk most closely "
            "matches cow's milk in protein content.\n\n"
            "Beverages to minimize or avoid include sugar-sweetened sodas and energy drinks, fruit juices "
            "(which are high in sugar even when 100% juice), sweetened coffee drinks that can contain 300 to "
            "600 calories and 40 to 80 grams of sugar per serving, sports drinks that contain significant sugar "
            "and are only necessary for sustained vigorous exercise lasting over 60 minutes, and alcohol. For "
            "people with diabetes, pre-diabetes, or obesity, replacing just one sweetened drink per day with "
            "water can reduce calorie intake by 150 to 300 calories per day."
        ),
    },
    {
        "id": "hypertension_diet_overview",
        "title": "Dietary Management of High Blood Pressure: Overview",
        "category": "Hypertension",
        "tags": ["hypertension", "diet", "dash", "blood pressure"],
        "source": "https://www.nhlbi.nih.gov/health/dash-eating-plan",
        "content": (
            "High blood pressure (hypertension) is defined as blood pressure consistently at or above "
            "130/80 mmHg for Stage 1, or 140/90 mmHg for Stage 2. It is called the silent killer because it "
            "typically has no symptoms but dramatically increases the risk of heart attack, stroke, kidney "
            "disease, and vision loss. Diet is one of the most powerful tools for both preventing and managing "
            "hypertension. Dietary changes can reduce systolic blood pressure by 8 to 14 mmHg, which is a "
            "reduction comparable to some blood pressure medications.\n\n"
            "The DASH diet (Dietary Approaches to Stop Hypertension) is the dietary pattern most strongly "
            "supported by evidence for lowering blood pressure. Developed and funded by the NIH/NHLBI, DASH has "
            "been tested in multiple large clinical trials and consistently reduces blood pressure in both people "
            "with hypertension and those with normal blood pressure. The DASH diet emphasizes fruits, vegetables, "
            "whole grains, lean proteins, and low-fat dairy, while limiting saturated fat, sodium, red meat, and "
            "added sugars. The blood pressure-lowering effect of the DASH diet is seen within 2 weeks of "
            "adoption.\n\n"
            "Sodium reduction is the single most impactful dietary change for blood pressure. The standard DASH "
            "sodium limit is 2,300 mg per day (approximately 1 teaspoon of table salt). A lower target of "
            "1,500 mg per day produces even greater blood pressure reductions of up to an additional 3 to 4 "
            "mmHg. In the United States, approximately 70 percent of dietary sodium comes from processed, "
            "packaged, and restaurant foods rather than from the salt shaker. Choosing products with less than "
            "5 percent Daily Value for sodium (less than 140 mg per serving) is a practical strategy.\n\n"
            "The potassium-sodium ratio in the diet is as important as sodium alone. Potassium counterbalances "
            "the blood pressure-raising effects of sodium by helping the kidneys excrete sodium in urine and by "
            "relaxing blood vessel walls. The target potassium intake for adults is 2,600 to 3,400 mg per day. "
            "High-potassium foods include bananas (422 mg), sweet potatoes (694 mg per medium potato), spinach "
            "(839 mg per cup cooked), white beans (829 mg per cup), avocado (708 mg per fruit), and lentils "
            "(731 mg per cup). People with kidney disease should consult their doctor before significantly "
            "increasing potassium.\n\n"
            "Alcohol significantly raises blood pressure and reduces the effectiveness of blood pressure "
            "medications. The AHA recommends limiting alcohol to no more than 1 drink per day for women and "
            "2 drinks per day for men. One drink is defined as 12 oz regular beer, 5 oz wine, or 1.5 oz "
            "spirits. Reducing or eliminating alcohol often produces a noticeable blood pressure reduction within "
            "weeks. Moderate coffee consumption of up to 3 cups per day is generally considered acceptable for "
            "most people with hypertension."
        ),
    },
    {
        "id": "hypertension_dash_meal_planning",
        "title": "DASH Diet: Meal Planning and Daily Targets",
        "category": "Hypertension",
        "tags": ["hypertension", "dash diet", "servings"],
        "source": "https://www.nhlbi.nih.gov/health/dash/living-with-dash, https://www.nhlbi.nih.gov/health/dash-eating-plan",
        "content": (
            "The DASH diet is a complete dietary pattern designed to be sustainable as a permanent way of "
            "eating, not a short-term intervention. Daily food group targets are based on a 2,000-calorie diet, "
            "which is approximately right for average-sized adults with moderate activity levels. Individual "
            "calorie needs vary and adjustments should be made accordingly.\n\n"
            "Grains: 6 to 8 servings per day, with at least half being whole grains. One serving equals 1 slice "
            "of bread, 1 ounce of dry cereal, or half a cup of cooked rice, pasta, or cereal. Whole grains such "
            "as brown rice, whole wheat bread and pasta, oats, quinoa, and barley provide fiber, B vitamins, and "
            "minerals that refined grains lack. Vegetables: 4 to 5 servings per day. One serving is 1 cup of raw "
            "leafy greens, half a cup of other vegetables (raw or cooked), or half a cup of vegetable juice. "
            "Fruits: 4 to 5 servings per day. One serving is one medium fruit, half a cup of fresh or frozen "
            "fruit, one-quarter cup of dried fruit, or three-quarters cup of 100% fruit juice.\n\n"
            "Low-fat dairy: 2 to 3 servings per day. One serving is 1 cup of milk or yogurt, or 1.5 ounces of "
            "cheese. Dairy provides calcium and magnesium, both of which contribute to blood pressure regulation. "
            "Fat-free or 1% milk and low-fat or non-fat yogurt are the recommended forms. People who are lactose "
            "intolerant can use lactose-free milk or calcium-fortified plant milks. Lean proteins: up to 6 ounces "
            "per day of lean meats, poultry without skin, or fish. Fish, particularly fatty fish like salmon, "
            "mackerel, and sardines, provides omega-3 fatty acids that support heart health and modest blood "
            "pressure reduction.\n\n"
            "Nuts, seeds, and legumes: 4 to 5 servings per week of unsalted nuts, seeds, and beans. These provide "
            "healthy fats, magnesium, potassium, and protein. A serving is one-third cup of nuts, 2 tablespoons of "
            "seeds or nut butter, or half a cup of cooked legumes. Fats and oils: 2 to 3 servings per day of "
            "heart-healthy fats, primarily olive oil. Sweets and added sugars: limit to 5 or fewer servings per "
            "week.\n\n"
            "Practical tips for following DASH: cook with olive oil instead of butter, choose whole grain versions "
            "of bread and pasta, eat a piece of fruit at every meal, include at least one vegetable with lunch and "
            "dinner, snack on unsalted nuts or low-fat yogurt instead of chips or cookies, and use herbs and "
            "spices for flavor instead of salt. The DASH diet does not require eliminating any food entirely. It "
            "is built around shifting proportions toward more plants, more whole grains, and less sodium and "
            "saturated fat."
        ),
    },
    {
        "id": "hypertension_sodium_reduction",
        "title": "Reducing Sodium: Practical Strategies",
        "category": "Hypertension",
        "tags": ["hypertension", "sodium", "salt", "blood pressure"],
        "source": "https://www.nhlbi.nih.gov/health/dash/sodium",
        "content": (
            "Reducing sodium intake is the most impactful single dietary change for blood pressure "
            "management. The standard recommendation is to stay below 2,300 mg per day, with greater benefits "
            "at 1,500 mg per day for most adults with hypertension. To put these numbers in perspective, one "
            "teaspoon of table salt contains approximately 2,300 mg of sodium. Most Americans consume "
            "3,400 mg per day on average, which is about 50 percent more than the general limit.\n\n"
            "The most effective strategy for reducing sodium is cooking from scratch using fresh ingredients, "
            "because restaurant food and packaged processed food are the largest sources of dietary sodium. "
            "When reading nutrition labels, look at the sodium per serving and check the percent Daily Value. "
            "A value of 5 percent DV (140 mg per serving) or less is considered low sodium. A value of 20 "
            "percent DV (460 mg per serving) or more is considered high sodium. Low-sodium versions of common "
            "staples such as canned beans, canned tomatoes, broths, and soy sauce are widely available and "
            "significantly reduce sodium without changing meal structure.\n\n"
            "Foods that are surprisingly high in sodium include deli meats and cold cuts (one serving can "
            "contain 500 to 1,000 mg), canned soups (a single can often contains 800 to 1,200 mg), fast food "
            "items (a burger and fries can exceed 2,000 mg), pizza, bread and rolls (consumed in large "
            "quantities even though each slice is a small sodium source per serving), cheese (cheddar contains "
            "about 175 mg per ounce), and condiments such as soy sauce (900 mg per tablespoon), teriyaki "
            "sauce, and Worcestershire sauce.\n\n"
            "Practical sodium-reduction strategies for cooking include rinsing canned beans and vegetables "
            "(which reduces sodium by 30 to 40 percent), using herbs and spices instead of salt (garlic, onion, "
            "lemon, vinegar, black pepper, cumin, rosemary, and thyme all add flavor without sodium), using "
            "lemon juice or citrus zest to brighten flavors, reducing the amount of salt in recipes by half "
            "(most people adjust within a few weeks as taste preferences adapt), and avoiding salt at the table.\n\n"
            "When eating out, strategies to reduce sodium include requesting sauces and dressings on the side, "
            "asking for less salt during cooking, choosing grilled or baked preparations rather than fried or "
            "breaded options, choosing broth-based soups over cream-based soups, skipping the bread basket, "
            "choosing lower-sodium sides such as a plain baked potato or steamed vegetables over fries, and "
            "reviewing nutrition information online before ordering at chain restaurants."
        ),
    },
    {
        "id": "hypertension_lifestyle_beyond_diet",
        "title": "Beyond Diet: Lifestyle Changes for Blood Pressure Management",
        "category": "Hypertension",
        "tags": ["hypertension", "lifestyle", "stress", "weight"],
        "source": "https://www.heart.org/en/health-topics/high-blood-pressure/changes-you-can-make-to-manage-high-blood-pressure",
        "content": (
            "Blood pressure management is most effective when multiple lifestyle factors are addressed "
            "simultaneously. While diet and exercise are the most evidence-backed interventions, weight "
            "management, stress reduction, smoking cessation, and medication adherence all play important roles.\n\n"
            "Excess weight, particularly abdominal or visceral fat, increases blood pressure through multiple "
            "mechanisms including increased fluid volume, hormonal changes, and increased arterial stiffness. "
            "Losing just 5 to 10 pounds can reduce systolic blood pressure by 1 to 4 mmHg. The full blood "
            "pressure benefit of losing 5 to 10 percent of body weight can be 5 to 10 mmHg, which is comparable "
            "to a blood pressure medication. Weight loss achieved through dietary changes plus exercise produces "
            "greater blood pressure improvements than dietary changes alone.\n\n"
            "Chronic stress raises blood pressure through the stress response system involving the sympathetic "
            "nervous system and cortisol release. While brief stress-induced blood pressure spikes are normal "
            "and harmless, chronically high stress is associated with sustained hypertension. Stress management "
            "techniques with evidence for blood pressure benefit include mindfulness meditation (which reduces "
            "systolic blood pressure by 3 to 5 mmHg in controlled studies), deep breathing exercises, yoga, "
            "regular physical activity, and adequate sleep.\n\n"
            "Smoking raises blood pressure acutely during and immediately after each cigarette and contributes to "
            "chronic hypertension over time through arterial damage and inflammation. People with hypertension "
            "who smoke have a substantially higher risk of heart attack and stroke than non-smokers with the "
            "same blood pressure levels. Smoking cessation is one of the highest-priority lifestyle changes for "
            "cardiovascular risk reduction in people with hypertension.\n\n"
            "For people taking blood pressure medication, medication adherence is critical. Many people stop "
            "taking their medication when they feel well, not realizing that hypertension causes no symptoms and "
            "that blood pressure rises again when medication is stopped. Lifestyle changes complement but do not "
            "always replace medication for people with moderate to severe hypertension. Regular home blood "
            "pressure monitoring using a validated monitor helps people stay informed about their actual blood "
            "pressure levels and motivates adherence to both lifestyle and medication regimens."
        ),
    },
    {
        "id": "prediabetes_understanding",
        "title": "Understanding Pre-Diabetes and Why Diet Matters",
        "category": "Pre-Diabetes",
        "tags": ["prediabetes", "blood sugar", "risk", "prevention"],
        "source": "https://www.cdc.gov/diabetes/prevention-type-2/prediabetes-prevent-type-2.html",
        "content": (
            "Pre-diabetes is a condition in which blood sugar levels are higher than normal but not yet high "
            "enough to be classified as type 2 diabetes. It is diagnosed when fasting blood glucose is between "
            "100 and 125 mg/dL, when the 2-hour result during an oral glucose tolerance test is between 140 and "
            "199 mg/dL, or when HbA1c is between 5.7 and 6.4 percent. Pre-diabetes affects approximately "
            "96 million American adults, about 1 in 3, and the vast majority are unaware they have it.\n\n"
            "Without lifestyle intervention, up to 70 percent of people with pre-diabetes will develop type 2 "
            "diabetes within 10 years. However, pre-diabetes is reversible. The landmark Diabetes Prevention "
            "Program (DPP) study demonstrated that lifestyle changes, specifically modest weight loss of 5 to 7 "
            "percent of body weight and 150 minutes per week of moderate physical activity, reduced progression "
            "from pre-diabetes to type 2 diabetes by 58 percent over 3 years. This effect was more powerful than "
            "the medication metformin, which reduced risk by 31 percent. Lifestyle change works.\n\n"
            "The dietary changes that most effectively prevent progression from pre-diabetes to diabetes focus on "
            "reducing overall calorie intake to achieve modest weight loss, reducing added sugars and refined "
            "carbohydrates (which cause rapid blood sugar spikes), increasing dietary fiber (which slows glucose "
            "absorption), and replacing saturated fats with healthier unsaturated fats. These changes do not "
            "require eliminating entire food groups or following a rigid diet plan.\n\n"
            "Carbohydrates have the most direct impact on blood sugar. When carbohydrates are digested, they are "
            "broken down into glucose and enter the bloodstream. Refined carbohydrates such as white bread, white "
            "rice, sugar, pastries, and sugary drinks are digested quickly and cause rapid spikes in blood sugar. "
            "Whole food carbohydrates including whole grains, legumes, non-starchy vegetables, and most fruits "
            "are digested more slowly due to their fiber content, producing gentler and more gradual rises in "
            "blood sugar.\n\n"
            "Even before significant weight loss is achieved, reducing calorie intake and making dietary "
            "improvements produces measurable improvements in blood sugar regulation. Each 1 kilogram "
            "(2.2 pounds) of weight loss is associated with approximately 0.1 mmol/L reduction in fasting blood "
            "glucose. A loss of 5 to 7 percent of body weight, which is just 10 to 14 pounds for a 200-pound "
            "person, is enough to produce clinically meaningful improvements in blood glucose, blood pressure, "
            "and cholesterol. The goal is improvement, not perfection."
        ),
    },
    {
        "id": "prediabetes_diet_strategies",
        "title": "Dietary Strategies for Pre-Diabetes Management",
        "category": "Pre-Diabetes",
        "tags": ["prediabetes", "diet", "blood sugar"],
        "source": "https://www.cdc.gov/diabetes/prevention-type-2/type-2-diabetes-prevention-guide.html",
        "content": (
            "Managing blood sugar through diet when you have pre-diabetes does not require a medically "
            "prescribed diet or counting carbohydrates precisely. It requires making consistent improvements to "
            "daily food choices. The most impactful changes are reducing sugary drinks, choosing whole grains "
            "over refined grains, increasing vegetable intake, reducing portion sizes, and limiting ultra-processed "
            "foods.\n\n"
            "Sugary beverages, including sodas, fruit juices, sweetened coffees and teas, and energy drinks, are "
            "the single most impactful food change for blood sugar management. These drinks deliver large amounts "
            "of sugar that are absorbed almost instantly into the bloodstream, causing sharp blood glucose spikes. "
            "Unlike solid food, liquid sugar does not trigger the same satiety signals, making it easy to consume "
            "large amounts without feeling full. Replacing just one 12-ounce soda per day, which contains "
            "approximately 39 grams of sugar, with water is a powerful first step.\n\n"
            "Choosing whole grain versions of starchy foods, such as whole wheat bread and pasta, brown rice, "
            "oats, quinoa, and barley, instead of refined counterparts significantly reduces the blood sugar "
            "impact of these foods. The fiber, protein, and micronutrient content of whole grains slows their "
            "digestion compared to refined grains. Reading ingredient labels for whole grain or whole wheat as "
            "the first ingredient helps identify truly whole grain products.\n\n"
            "The plate method is a practical tool for managing blood sugar at meals without counting "
            "carbohydrates. Fill half the plate with non-starchy vegetables such as leafy greens, broccoli, "
            "cauliflower, peppers, cucumber, zucchini, mushrooms, and onions. Fill one quarter of the plate "
            "with a quality protein source such as chicken, fish, eggs, beans, or tofu. Fill the remaining "
            "quarter with a whole grain or starchy vegetable such as brown rice, sweet potato, corn, or beans. "
            "Drink water or an unsweetened beverage.\n\n"
            "Eating patterns affect blood sugar regulation as much as food choices do. Eating regular meals at "
            "consistent times helps prevent large swings in blood glucose. Skipping meals, particularly "
            "breakfast, is associated with larger post-meal blood sugar spikes later in the day. Including "
            "protein and fiber with every meal or snack slows the absorption of carbohydrates and reduces blood "
            "glucose peaks. Eating slowly and mindfully, giving the body time to register fullness before "
            "overeating, also supports portion control."
        ),
    },
    {
        "id": "prediabetes_foods_to_choose",
        "title": "Best Foods for Pre-Diabetes Management",
        "category": "Pre-Diabetes",
        "tags": ["prediabetes", "foods", "low glycemic", "nutrition"],
        "source": "https://diabetes.org/food-nutrition/eating-healthy",
        "content": (
            "No single food reverses pre-diabetes, but a consistent pattern of choosing nutrient-dense, "
            "lower-glycemic foods significantly supports blood sugar regulation and weight management. Certain "
            "foods are particularly beneficial for people with pre-diabetes due to their specific nutritional "
            "profiles.\n\n"
            "Non-starchy vegetables are the foundation of a pre-diabetes diet. They are very low in "
            "carbohydrates and calories, high in fiber, vitamins, and minerals, and have virtually no effect on "
            "blood sugar. The full list includes spinach, kale, lettuce, arugula, Swiss chard, collard greens, "
            "cabbage, broccoli, cauliflower, Brussels sprouts, green beans, asparagus, zucchini, cucumber, "
            "celery, bell peppers in all colors, tomatoes, mushrooms, onions, garlic, radishes, and eggplant. "
            "These vegetables can be eaten in large quantities without blood sugar concerns.\n\n"
            "Legumes including beans, lentils, and peas are among the best foods for blood sugar management. "
            "They have a very low glycemic index due to their combination of protein, fiber, and resistant "
            "starch, which results in a slow and gradual rise in blood sugar after eating. A half-cup serving "
            "of cooked black beans provides about 20 grams of carbohydrates, 7 to 8 grams of fiber, and 8 grams "
            "of protein, significantly slowing its digestion. Lentils, chickpeas, kidney beans, navy beans, and "
            "split peas are all excellent options.\n\n"
            "Fatty fish including salmon, sardines, mackerel, herring, and trout provide omega-3 fatty acids "
            "that reduce inflammation, which plays a role in insulin resistance. Including fatty fish 2 to 3 "
            "times per week provides cardiovascular benefits alongside blood sugar management benefits. Eggs are "
            "a high-quality protein food with no effect on blood sugar. Nuts and seeds in moderate portions of "
            "1 to 1.5 ounces provide healthy fats, protein, and fiber that reduce the blood sugar impact of a "
            "meal or snack.\n\n"
            "Whole fruits, particularly berries, apples, pears, and citrus fruits, are appropriate for people "
            "with pre-diabetes when eaten in reasonable portions of one medium piece of fruit or half a cup of "
            "berries. Despite containing natural sugar, whole fruits have a lower glycemic impact than fruit "
            "juices because their fiber slows sugar absorption. Berries are particularly high in fiber and "
            "antioxidants and among the lowest in sugar of all fruits. Eating fruit as part of a meal with "
            "protein and fat further reduces the blood sugar response. Limiting fruit to 1 to 2 servings per "
            "day is a reasonable guideline."
        ),
    },
    {
        "id": "diabetes_carb_management",
        "title": "Managing Carbohydrates with Type 2 Diabetes",
        "category": "Diabetes",
        "tags": ["diabetes", "carbohydrates", "blood sugar", "management"],
        "source": "https://diabetes.org/food-nutrition/eating-for-diabetes-management",
        "content": (
            "Carbohydrate management is the cornerstone of dietary management for type 2 diabetes. All "
            "carbohydrates including sugars, starches, and some fibers are eventually broken down into glucose "
            "and absorbed into the bloodstream. In people with type 2 diabetes, either insufficient insulin is "
            "produced by the pancreas, or the body's cells are resistant to insulin's effects, which means blood "
            "glucose rises higher and stays elevated longer after eating carbohydrate-containing foods.\n\n"
            "There is no single correct carbohydrate intake target for all people with diabetes. Carbohydrate "
            "targets depend on individual factors including the type of diabetes management approach (diet alone, "
            "medication, or insulin), weight loss goals, kidney function, other health conditions, and individual "
            "blood glucose responses to specific foods. The most important principle is consistency. Eating "
            "similar amounts of carbohydrate at similar times each day helps stabilize blood sugar levels. Large "
            "variations in carbohydrate intake from meal to meal or day to day make blood sugar management much "
            "more difficult.\n\n"
            "Carbohydrate counting is a practical method used by many people with diabetes. A general starting "
            "target is 45 to 60 grams of carbohydrate per main meal and 15 to 30 grams for snacks, though these "
            "targets should be personalized with a registered dietitian or diabetes educator. One carbohydrate "
            "choice or serving is equivalent to 15 grams of carbohydrate. Examples include 1 slice of bread, "
            "one-third cup of pasta or rice cooked, half a cup of oatmeal, one small piece of fruit, half a cup "
            "of cooked legumes, and three-quarters cup of most cereals.\n\n"
            "Spreading carbohydrate intake evenly throughout the day is more effective than consuming large amounts "
            "at any single meal. A very carbohydrate-heavy meal such as a large plate of white rice or pasta will "
            "raise blood sugar significantly even if the daily total is within range. Three moderate meals and "
            "one to two small snacks, each with a similar carbohydrate content, supports more stable blood glucose "
            "throughout the day. Including protein and fat with each carbohydrate source further slows absorption.\n\n"
            "Fiber is a type of carbohydrate that is not digested and absorbed in the same way as sugars and "
            "starches. Soluble fiber in particular, found in oats, beans, lentils, apples, pears, and psyllium, "
            "slows the absorption of glucose and improves blood sugar response after meals. The ADA recommends "
            "that people with diabetes aim for at least 25 grams of fiber per day. High-fiber foods are typically "
            "lower on the glycemic index and more filling, supporting both blood sugar management and weight "
            "control."
        ),
    },
    {
        "id": "diabetes_meal_patterns",
        "title": "Diabetes Plate Method and Meal Patterns",
        "category": "Diabetes",
        "tags": ["diabetes", "plate method", "meals", "portion"],
        "source": "https://diabetes.org/food-nutrition/eating-healthy",
        "content": (
            "The Diabetes Plate Method is a simple, practical approach to building balanced meals without "
            "counting carbohydrates or measuring food. Developed by the American Diabetes Association, it uses a "
            "standard 9-inch dinner plate as a visual guide for appropriate food proportions at each meal.\n\n"
            "Half the plate should be filled with non-starchy vegetables. These include spinach, kale, lettuce, "
            "cabbage, broccoli, cauliflower, green beans, peppers, mushrooms, onions, tomatoes, cucumbers, "
            "zucchini, asparagus, and celery. Non-starchy vegetables are very low in carbohydrates and have "
            "minimal impact on blood sugar, so they can be eaten in large quantities. They provide important "
            "fiber, vitamins, minerals, and antioxidants. They also add volume to the meal, which promotes "
            "fullness and reduces the tendency to eat more high-carbohydrate or high-calorie foods.\n\n"
            "One quarter of the plate should be filled with quality protein. Lean protein choices include skinless "
            "chicken and turkey, fish (particularly fatty fish like salmon and sardines), eggs, low-fat cottage "
            "cheese, tofu and tempeh, edamame, and legumes such as beans and lentils. Protein does not directly "
            "raise blood sugar and provides lasting satiety. Red and processed meats should be limited, as they "
            "are associated with increased risk of heart disease and colorectal cancer.\n\n"
            "One quarter of the plate should be filled with quality carbohydrates. High-quality carbohydrate "
            "choices include whole grains (brown rice, quinoa, whole wheat pasta, oats, barley), starchy "
            "vegetables (sweet potato, corn, peas, winter squash), legumes (beans, lentils, chickpeas), and "
            "whole fruit. These carbohydrates are digested more slowly than refined carbohydrates and have a "
            "lower glycemic impact. The portion in this quarter of a 9-inch plate is automatically appropriate "
            "at roughly half to three-quarters of a cup of cooked grain or starchy vegetable.\n\n"
            "To complete a Diabetes Plate meal, include a small serving of healthy fat such as a slice of "
            "avocado, a drizzle of olive oil, or a small handful of nuts. Choose a low-calorie, non-sugary "
            "beverage, preferably water or unsweetened tea. Eat at a moderate pace, giving the body time to "
            "signal fullness before finishing the plate. Eating the vegetables first, then protein, then "
            "carbohydrates, has been shown in small studies to significantly reduce post-meal blood glucose "
            "compared to eating carbohydrates first."
        ),
    },
    {
        "id": "diabetes_foods_glycemic",
        "title": "Glycemic Index, Glycemic Load, and Smart Food Choices for Diabetes",
        "category": "Diabetes",
        "tags": ["diabetes", "glycemic index", "carbs", "blood sugar"],
        "source": "https://diabetes.org/food-nutrition/eating-for-diabetes-management",
        "content": (
            "The glycemic index (GI) is a ranking system that measures how quickly a specific "
            "carbohydrate-containing food raises blood sugar compared to pure glucose. Foods are ranked on a "
            "scale of 0 to 100. Low GI foods at 55 or below cause a slow, gradual rise in blood glucose. High GI "
            "foods at 70 or above cause a rapid spike. Medium GI foods fall between 56 and 69.\n\n"
            "Low GI foods to prioritize include rolled or steel-cut oats (GI 55), most legumes including lentils "
            "(GI 32), kidney beans (GI 24), chickpeas (GI 28), most fruits including apples (GI 36), pears "
            "(GI 38), and oranges (GI 43). Most non-starchy vegetables have a GI below 15. Brown rice has a GI "
            "of approximately 50 to 55, compared to white rice at 64 to 72. Whole grain bread (GI 50 to 60) is "
            "significantly lower than white bread (GI 71 to 77).\n\n"
            "High GI foods to limit or combine with protein and fat include white bread (GI 71 to 77), white rice "
            "(GI 64 to 72), instant oatmeal (GI 79), watermelon (GI 72), corn flakes (GI 81), pretzels (GI 83), "
            "rice cakes (GI 82), and most sugary drinks and sweets. These foods cause rapid blood glucose spikes "
            "and should be eaten in small portions if at all, always combined with protein, fat, and fiber to "
            "slow their absorption.\n\n"
            "Glycemic load (GL) is a more practical measure than GI because it accounts for both the GI of a food "
            "and the amount of carbohydrate in a typical serving. Carrots are a common example. They have a "
            "relatively high GI of about 71 but a low glycemic load because a typical serving contains only "
            "6 grams of carbohydrate, meaning the actual blood sugar impact is small. Watermelon has a high GI "
            "but a moderate GL when eaten in a reasonable portion.\n\n"
            "Rather than memorizing GI numbers, the practical application is to focus on the underlying principles. "
            "Foods that are less processed and have more fiber, more protein, or more fat tend to have lower "
            "glycemic impact. Combining carbohydrates with protein and fat at every meal, as the Diabetes Plate "
            "Method does, is the simplest way to reduce the overall glycemic impact of meals. Cooking method also "
            "matters. Al dente pasta has a lower GI than well-cooked pasta. Cold or cooled cooked starches such "
            "as potato salad made with cooled potatoes have a lower GI than the same foods served hot."
        ),
    },
    {
        "id": "obesity_understanding",
        "title": "Understanding Obesity and Its Health Effects",
        "category": "Obesity",
        "tags": ["obesity", "weight", "risk", "diabetes"],
        "source": "https://www.niddk.nih.gov/health-information/weight-management/adult-overweight-obesity",
        "content": (
            "Obesity is defined by the CDC as a body mass index (BMI) of 30 or above. BMI is calculated by "
            "dividing weight in kilograms by height in meters squared. While BMI is a useful screening tool, it "
            "does not directly measure body fat and does not account for differences in muscle mass, bone density, "
            "or fat distribution. Waist circumference is an important complementary measure. A waist circumference "
            "above 40 inches for men or 35 inches for women indicates central (abdominal) obesity, which is more "
            "strongly linked to metabolic disease than overall BMI alone.\n\n"
            "Obesity significantly increases the risk of over 200 health conditions including type 2 diabetes, "
            "hypertension, heart disease, stroke, certain cancers (including breast, colon, and kidney), sleep "
            "apnea, osteoarthritis, fatty liver disease, gallbladder disease, and depression. The relationship "
            "between obesity and type 2 diabetes is particularly strong. Approximately 90 percent of people with "
            "type 2 diabetes are overweight or obese, and obesity is the most significant modifiable risk factor "
            "for developing the disease.\n\n"
            "The causes of obesity are complex and multifactorial. While the fundamental mechanism involves an "
            "imbalance between calorie intake and calorie expenditure, many biological, psychological, social, "
            "and environmental factors influence this balance. Genetics account for approximately 40 to 70 percent "
            "of BMI variation. Hormonal conditions, certain medications including some antidepressants and "
            "corticosteroids, chronic stress, poor sleep, limited access to healthy food, and built environment "
            "factors all contribute to obesity risk and management challenges.\n\n"
            "Even modest weight loss produces significant health benefits. Losing just 5 to 10 percent of body "
            "weight, which is 10 to 20 pounds for a 200-pound person, produces clinically meaningful reductions "
            "in blood pressure (5 to 10 mmHg), fasting blood glucose (3 to 5 mg/dL), LDL cholesterol, and "
            "triglycerides. These improvements reduce cardiovascular risk and can delay or prevent the development "
            "of type 2 diabetes in people with pre-diabetes. The emphasis should be on achievable health "
            "improvements rather than reaching an idealized body weight.\n\n"
            "Sustainable weight management requires addressing behavioral, environmental, and potentially biological "
            "factors. Evidence-based approaches include calorie-controlled dietary patterns, regular physical "
            "activity, behavioral strategies such as goal-setting and self-monitoring, social support, and "
            "management of psychological factors contributing to eating behavior. For some people, medical or "
            "surgical treatment is also appropriate. People trying to manage their weight should receive "
            "compassionate, non-judgmental support that addresses the full complexity of their situation."
        ),
    },
    {
        "id": "obesity_dietary_approaches",
        "title": "Effective Dietary Approaches for Weight Management",
        "category": "Obesity",
        "tags": ["obesity", "diet", "calorie deficit", "weight loss"],
        "source": "https://www.niddk.nih.gov/health-information/weight-management/adult-overweight-obesity/eating-physical-activity",
        "content": (
            "No single dietary approach is definitively superior for weight loss across all individuals. Multiple "
            "dietary patterns including low-fat, low-carbohydrate, Mediterranean, DASH, and plant-based approaches "
            "all produce clinically meaningful weight loss when they create a sustained calorie deficit and are "
            "followed consistently over time. The best dietary approach for weight management is the one an "
            "individual can sustain over the long term, given their food preferences, cultural background, "
            "schedule, and health conditions.\n\n"
            "A modest calorie deficit of 500 to 750 calories per day below energy needs is the most commonly "
            "recommended approach for achieving a weight loss rate of approximately 1 to 1.5 pounds per week. "
            "This pace is associated with better long-term maintenance than rapid weight loss. Minimum daily "
            "calorie intake should generally not fall below 1,200 calories per day for women or 1,500 calories "
            "per day for men without medical supervision, as very low calorie diets increase risk of nutrient "
            "deficiency, muscle loss, and metabolic adaptation.\n\n"
            "High-protein dietary patterns are consistently beneficial for weight management because protein is "
            "the most satiating macronutrient. It reduces hunger hormones, increases feelings of fullness, and "
            "preserves muscle mass during weight loss, which helps maintain metabolic rate. Dietary protein "
            "targets for weight management are generally 1.2 to 1.6 grams per kilogram of body weight per day. "
            "High-quality protein sources include eggs, lean poultry, fish, low-fat dairy, legumes, tofu, and "
            "edamame.\n\n"
            "High-fiber foods are strongly associated with greater weight loss and improved weight maintenance. "
            "Fiber increases meal volume, slows digestion, promotes satiety hormones, and feeds beneficial gut "
            "bacteria. A practical approach is to build meals around high-fiber, low-calorie-density foods: "
            "non-starchy vegetables (which are 90 to 95 percent water and fiber), legumes, whole fruits, and "
            "whole grains. These foods allow larger meal volumes, which provide visual and psychological "
            "satisfaction, while staying within calorie targets.\n\n"
            "Meal frequency and timing strategies can support weight management for some individuals. Eating "
            "regular meals rather than skipping breakfast or lunch and consuming most calories at dinner helps "
            "regulate appetite hormones throughout the day. Time-restricted eating, such as limiting food intake "
            "to an 8 to 10-hour window each day, is a form of intermittent fasting that some people find easier "
            "to sustain than daily calorie counting. Any regular eating pattern that creates a modest calorie "
            "deficit and is sustainable is a valid approach."
        ),
    },
    {
        "id": "obesity_behavior_strategies",
        "title": "Behavioral Strategies for Sustainable Weight Management",
        "category": "Obesity",
        "tags": ["obesity", "behavior", "habits", "weight management"],
        "source": "https://www.niddk.nih.gov/health-information/weight-management/adult-overweight-obesity/treatment",
        "content": (
            "Dietary knowledge is necessary but not sufficient for successful weight management. Behavioral "
            "strategies, which are the practical tools for translating knowledge into consistent daily action, are "
            "the key determinants of long-term success. Research consistently shows that people who lose weight "
            "and maintain the loss over years use specific behavioral techniques rather than relying solely on "
            "motivation or willpower.\n\n"
            "Self-monitoring, which includes tracking food intake, physical activity, and weight, is the most "
            "consistently effective behavioral strategy for weight management across multiple large reviews. "
            "Tracking food intake increases awareness of what and how much is being eaten, highlights problematic "
            "patterns such as mindless snacking or specific high-calorie triggers, and provides objective data "
            "for problem-solving. Weekly weigh-ins are more effective than daily weighing for detecting true "
            "trends, as daily weight fluctuates by 1 to 3 pounds due to hydration, sodium intake, and digestive "
            "contents.\n\n"
            "Goal-setting using SMART goals (Specific, Measurable, Achievable, Relevant, and Time-bound) is more "
            "effective than vague intentions. The statement 'I will walk 30 minutes after dinner on Monday, "
            "Wednesday, and Friday this week' is more actionable and achievable than 'I will exercise more.' "
            "Process goals that focus on specific behaviors are more effective for building habits than outcome "
            "goals focused on weight alone. Celebrating small wins and planning for predictable challenges such "
            "as travel, holidays, and social events are important components of sustainable behavior change.\n\n"
            "Identifying and managing triggers for overeating or unhealthy eating is a key component of behavioral "
            "weight management. Common triggers include emotional states such as stress, boredom, loneliness, or "
            "anxiety; environmental cues such as seeing or smelling food or keeping high-calorie foods visible; "
            "social situations such as eating out or family gatherings; and habitual patterns such as snacking "
            "while watching TV. Strategies for managing triggers include removing high-calorie foods from the "
            "home, eating only while seated at a table, keeping lower-calorie foods readily available, and "
            "developing non-food responses to emotional triggers.\n\n"
            "Social support significantly improves weight management outcomes. People who involve family members "
            "or friends in their weight management efforts, or who participate in structured support groups such "
            "as the CDC Diabetes Prevention Program, achieve better results than those trying to manage alone. "
            "Healthcare providers, registered dietitians, and certified diabetes educators can provide "
            "personalized guidance, accountability, and support. Regular appointments with a supportive "
            "healthcare team are associated with better long-term outcomes than self-directed approaches alone."
        ),
    },
    {
        "id": "mindful_eating",
        "title": "Mindful Eating: Eating Well Without Strict Rules",
        "category": "General",
        "tags": ["eating habits", "mindful eating", "hunger", "weight"],
        "source": "https://www.hsph.harvard.edu/nutritionsource/mindful-eating/",
        "content": (
            "Mindful eating is the practice of paying full attention to the experience of eating, including the "
            "taste, texture, smell, and appearance of food, and to internal cues like hunger and fullness, rather "
            "than eating automatically, quickly, or in response to external triggers. It is not a diet with rules "
            "about what to eat, but a way of approaching eating that can complement any dietary approach for "
            "managing chronic health conditions.\n\n"
            "Hunger and fullness cues are often overridden by habit, emotion, environment, and eating speed. "
            "Eating quickly makes it easy to overshoot fullness because it takes approximately 15 to 20 minutes "
            "for signals from the gut to reach the brain indicating that enough food has been consumed. Eating "
            "slowly by putting down the fork between bites, chewing thoroughly, and pausing halfway through the "
            "meal to assess hunger level allows these signals to be received before overeating occurs. Studies "
            "show that simply eating more slowly reduces calorie intake at meals without changing food choices.\n\n"
            "The hunger scale is a simple mindful eating tool. On a scale of 1 (extremely hungry and famished) "
            "to 10 (uncomfortably full), most people do best eating when hunger is around a 3 to 4 (moderately "
            "hungry but not ravenous) and stopping around 6 to 7 (satisfied but not full). Eating when extremely "
            "hungry at a level of 1 to 2 makes it very difficult to eat slowly and choose well, as urgent hunger "
            "overrides thoughtful decision-making. Eating past a level of 8 to 9 (full or overly full) on a "
            "regular basis is associated with weight gain and digestive discomfort.\n\n"
            "Emotional eating, which means eating in response to emotions such as stress, boredom, loneliness, "
            "anxiety, or sadness rather than physical hunger, is extremely common and a significant driver of "
            "excess calorie intake. Identifying emotional eating patterns is the first step to managing them. "
            "Keeping a simple food and mood journal by noting what was eaten, when, and what was being felt at "
            "the time can reveal patterns. Developing a toolkit of non-food responses to emotional triggers such "
            "as a short walk, calling a friend, a brief breathing exercise, or a hobby provides alternatives to "
            "turning to food.\n\n"
            "Practical mindful eating strategies include eating at a table without distractions such as phones, "
            "TV, or computer; serving appropriate portions on a plate rather than eating from packages; using "
            "smaller plates and bowls, which visually suggest adequate portions; beginning meals with a glass of "
            "water; eating vegetables or salad first; taking three deep breaths before starting to eat; pausing "
            "halfway through the meal to assess fullness; and stopping eating when satisfied rather than when the "
            "plate is empty. Adopting even one or two of these practices consistently produces meaningful "
            "improvements in eating awareness and satisfaction."
        ),
    },
    {
        "id": "food_environment_budgeting",
        "title": "Eating Well on a Budget and in Challenging Environments",
        "category": "General",
        "tags": ["budget", "meal planning", "healthy eating", "weight"],
        "source": "https://www.myplate.gov/eat-healthy/healthy-eating-budget, https://cdn.realfood.gov/DGA.pdf",
        "content": (
            "Cost and food access are real barriers to healthy eating that affect millions of Americans. Health "
            "conditions disproportionately affect people with lower incomes, and dietary guidance that ignores the "
            "realities of food cost and access is not practically useful. Eating well on a budget is possible, and "
            "the strategies below require no special equipment or unusual ingredients.\n\n"
            "The most affordable nutrient-dense foods include canned and dried legumes such as beans, lentils, "
            "and chickpeas (which are among the cheapest sources of protein and fiber available); eggs (an "
            "excellent and affordable protein); frozen vegetables (nutritionally equivalent to fresh and often "
            "cheaper, especially for berries and out-of-season vegetables); oats (an extremely cheap whole grain "
            "that is versatile and high in fiber); bananas (among the cheapest fruits and an excellent potassium "
            "source); canned fish such as tuna, sardines, and salmon (affordable and high in omega-3 fatty acids); "
            "and root vegetables like carrots, sweet potatoes, and cabbage (nutritious, filling, and inexpensive).\n\n"
            "Meal planning and batch cooking significantly reduce food costs and the likelihood of defaulting to "
            "expensive, less healthy options when tired or short on time. Planning a week's meals in advance, "
            "writing a grocery list based on the plan, and shopping with that list reduces food waste and food "
            "spending. Cooking larger batches of a pot of beans, a tray of roasted vegetables, or a batch of "
            "grains that can be portioned and used across multiple meals is highly time-efficient and cost-effective.\n\n"
            "Frozen and canned foods are underappreciated allies in healthy eating. Frozen vegetables and fruits "
            "are picked at peak ripeness and immediately frozen, preserving most of their nutritional value. "
            "Choosing frozen vegetables without added salt or sauces, and canned vegetables rinsed to remove "
            "sodium, makes them fully equivalent to fresh. Canned beans (rinsed) and canned tomatoes (no salt "
            "added) are pantry staples that form the basis of dozens of quick, affordable, and nutritious meals.\n\n"
            "When eating at restaurants, strategies to maintain healthy eating include reviewing the menu online "
            "before arriving and deciding in advance, requesting dressings and sauces on the side, choosing grilled "
            "or baked preparations over fried, asking for extra vegetables in place of a starch, and sharing an "
            "entree or taking half home immediately. At social gatherings, eating a small nutritious snack before "
            "arriving reduces hunger that might otherwise lead to overdoing high-calorie party food. Identifying "
            "and preparing go-to healthy options for personally challenging situations such as work vending "
            "machines, airport food courts, or family gatherings in advance makes it much easier to maintain "
            "healthy habits in real-world conditions."
        ),
    },
    {
        "id": "myplate_overview",
        "title": "What Is MyPlate? The USDA Guide to Healthy Eating",
        "category": "General",
        "tags": ["myplate", "balanced diet", "portion", "nutrition"],
        "source": "https://www.myplate.gov/eat-healthy/what-is-myplate, https://www.myplate.gov/eat-healthy/fruits, https://www.myplate.gov/eat-healthy/vegetables, https://www.myplate.gov/eat-healthy/grains, https://www.myplate.gov/eat-healthy/protein-foods, https://www.myplate.gov/eat-healthy/dairy",
        "content": (
            "MyPlate is the United States Department of Agriculture's (USDA) visual guide to healthy eating, "
            "introduced in 2011 to replace the older food pyramid. It represents a standard dinner plate divided "
            "into four sections: fruits, vegetables, grains, and protein, with a smaller circle beside it for dairy. "
            "The key message is simple: half of every plate should be fruits and vegetables, one quarter should be "
            "whole grains, and one quarter should be lean protein, with a serving of low-fat dairy alongside.\n\n"
            "MyPlate is built on five food groups. Vegetables should make up the largest portion of the plate. "
            "The recommendation is to eat a variety of vegetables including dark green types such as spinach and "
            "broccoli; red and orange types such as tomatoes, carrots, and sweet potatoes; legumes such as beans, "
            "peas, and lentils; starchy types such as corn and potatoes; and other types such as zucchini, onions, "
            "and mushrooms. Aim for 2 to 3 cups of vegetables per day for most adults. Fruits should make up a "
            "smaller but equally important part of the diet. Whole fruits are preferred over fruit juices because "
            "they contain fiber and produce a slower blood sugar response. Fresh, frozen, canned (in water or "
            "100% juice, not syrup), and dried fruits all count. Aim for about 1.5 to 2 cups per day for most adults.\n\n"
            "Grains should make up one quarter of the plate, and at least half of all grains eaten should be whole "
            "grains. Whole grains include whole wheat bread, brown rice, oatmeal, whole grain pasta, quinoa, "
            "barley, and popcorn. Refined grains such as white bread, white rice, and regular pasta have had the "
            "bran and germ removed, which takes away most of the fiber, iron, and B vitamins. Choosing 100% "
            "whole wheat bread and brown rice instead of white versions is one of the simplest grain improvements "
            "anyone can make.\n\n"
            "Protein foods should make up one quarter of the plate. Choose lean or low-fat options most often. "
            "Good protein choices include seafood (especially fatty fish like salmon twice per week), poultry "
            "(chicken, turkey without skin), eggs, beans and peas, nuts, seeds, soy products such as tofu and "
            "edamame, and lean cuts of beef or pork (such as tenderloin, sirloin, or extra-lean ground beef). "
            "Processed meats like sausage, bacon, and deli meats are high in sodium and saturated fat and should "
            "be limited. Dairy such as fat-free or low-fat (1%) milk, yogurt, and cheese provides calcium, "
            "potassium, and vitamin D. People who are lactose intolerant can substitute fortified soy milk, "
            "which has comparable protein and nutrients.\n\n"
            "MyPlate applies to people with all of the health conditions covered by the MyFoodRx app. For "
            "hypertension: emphasize the potassium-rich fruits, vegetables, and dairy on the plate and keep sodium "
            "low. For diabetes and pre-diabetes: the quarter-plate carbohydrate portion with whole grains, "
            "combined with the half-plate of non-starchy vegetables, naturally controls the glycemic impact of "
            "meals. For obesity: the plate structure automatically controls portions without requiring counting or "
            "weighing food. The Dietary Guidelines for Americans 2025-2030 reinforce these principles, recommending "
            "3 servings of vegetables per day, 2 servings of fruit per day, and 2 to 4 servings of whole grains, "
            "with protein and dairy alongside."
        ),
    },
    {
        "id": "myplate_portion_sizes",
        "title": "Understanding Serving Sizes and Portions",
        "category": "General",
        "tags": ["portion size", "servings", "myplate", "weight"],
        "source": "https://www.myplate.gov/eat-healthy/what-is-myplate, https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label",
        "content": (
            "A serving size is a standardized amount of food used to measure nutrients, as shown on a Nutrition "
            "Facts label. A portion is how much food you actually eat at one time. The two are not always the "
            "same. A bag of chips might list a serving size as 1 ounce (about 15 chips), but most people eat "
            "significantly more than that in one sitting. Understanding serving sizes helps with accurate "
            "nutrition tracking and calorie management.\n\n"
            "Visual cues make estimating portion sizes easy without scales or measuring cups. One cup of food "
            "(such as cooked pasta, rice, or vegetables) is roughly the size of a baseball or a clenched fist. "
            "Three ounces of cooked meat or fish (a standard single serving) is about the size of a deck of cards "
            "or the palm of your hand. One ounce of cheese is roughly the size of four stacked dice. One tablespoon "
            "of peanut butter, oil, or butter is about the size of a poker chip or your thumb tip. One medium piece "
            "of fruit (apple, orange, pear) is approximately the size of a tennis ball.\n\n"
            "Common serving sizes for each food group in the MyPlate framework are as follows. For grains: "
            "1 ounce equivalent is 1 slice of bread, 1 cup of ready-to-eat cereal, or half a cup of cooked rice, "
            "pasta, or cooked cereal. For vegetables: 1 cup equivalent is 1 cup of raw or cooked vegetables or "
            "vegetable juice, or 2 cups of raw leafy greens. For fruits: 1 cup equivalent is 1 cup of fruit or "
            "100% fruit juice, or half a cup of dried fruit. For protein: 1 ounce equivalent is 1 ounce of cooked "
            "meat, poultry, or seafood; 1 egg; a quarter cup of cooked beans; 1 tablespoon of peanut butter; or "
            "half an ounce of nuts or seeds. For dairy: 1 cup equivalent is 1 cup of milk or yogurt, or 1.5 ounces "
            "of natural cheese.\n\n"
            "Portion sizes in the United States have grown significantly over the past 30 years. A standard "
            "restaurant meal often contains 2 to 3 times the recommended serving sizes for many foods. Studies "
            "show that people consistently eat more when they are served larger portions, regardless of hunger "
            "level. Using smaller plates (9-inch rather than 12-inch dinner plates), serving food from the kitchen "
            "rather than placing serving dishes at the table, and dividing restaurant portions in half at the start "
            "of a meal (boxing the rest immediately) are practical strategies for managing portions without feeling "
            "deprived.\n\n"
            "People managing diabetes or pre-diabetes benefit particularly from consistent portion sizes at meals, "
            "as the same food eaten in different amounts produces very different blood glucose responses. The "
            "carbohydrate portion of a meal (the quarter plate of grains or starchy vegetables) should stay "
            "roughly consistent from meal to meal. People managing hypertension benefit from attention to sodium "
            "per serving on labels rather than per package, as many products appear low-sodium but contain multiple "
            "servings per container. People managing obesity benefit from filling half the plate with non-starchy "
            "vegetables first before adding protein and grains, which reduces total calorie density while increasing "
            "meal volume and satiety."
        ),
    },
    {
        "id": "reading_nutrition_labels",
        "title": "How to Read a Nutrition Facts Label",
        "category": "General",
        "tags": ["nutrition labels", "sodium", "sugar", "servings"],
        "source": "https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label, https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels",
        "content": (
            "The Nutrition Facts label on packaged food is one of the most useful tools available for making "
            "informed food choices. In the United States, the FDA requires this label on almost all packaged foods. "
            "Understanding how to read it accurately helps people with chronic conditions make choices that directly "
            "support their health goals.\n\n"
            "Start at the top: serving size and servings per container. This is the most important part of the label "
            "because all the numbers below (calories, nutrients, percent Daily Values) apply to one serving, not "
            "the whole package. If a bag contains 3 servings and you eat the whole bag, you need to multiply every "
            "number by 3. The serving size listed is not necessarily a recommended amount; it reflects what the FDA "
            "considers a typical amount eaten, which is often much less than what people actually consume.\n\n"
            "Calories tell you how much energy is in one serving. For reference, the average adult needs "
            "approximately 2,000 calories per day, though this varies significantly by age, sex, height, weight, "
            "and activity level. The percent Daily Value (%DV) column on the right side of the label shows how "
            "much of a nutrient one serving provides relative to the recommended daily intake. A simple rule: "
            "5% DV or less is considered low for a nutrient, and 20% DV or more is considered high. Use this to "
            "quickly identify foods high in beneficial nutrients or high in nutrients to limit.\n\n"
            "Nutrients to limit: saturated fat, sodium, and added sugars. Saturated fat raises LDL (bad) "
            "cholesterol and increases heart disease risk. The daily limit is less than 10% of calories, which is "
            "about 20 grams on a 2,000-calorie diet. Sodium (salt) raises blood pressure. The daily limit is "
            "2,300 mg, or 1,500 mg for people with hypertension. Added sugars contribute calories without nutrition. "
            "The AHA recommends no more than 25 grams (6 teaspoons) per day for women and 36 grams (9 teaspoons) "
            "for men. Ingredients that indicate added sugar on labels include high-fructose corn syrup, cane sugar, "
            "dextrose, fructose, maltose, molasses, honey, and agave.\n\n"
            "Nutrients to get enough of: dietary fiber, vitamin D, calcium, iron, and potassium. Most Americans "
            "do not get enough of these. Fiber supports blood sugar management, heart health, and digestive "
            "function. Aim for 25 to 38 grams per day. Potassium helps lower blood pressure and counteracts sodium. "
            "Foods high in potassium are important for people managing hypertension. The ingredients list below the "
            "nutrition panel lists all ingredients in order from most to least by weight. If sugar or refined grains "
            "appear in the first three ingredients, the product is high in those components. Shorter ingredient "
            "lists with recognizable whole foods generally indicate less processed products."
        ),
    },
    {
        "id": "heart_healthy_fats",
        "title": "Heart-Healthy Fats: What to Choose and What to Limit",
        "category": "General",
        "tags": ["fats", "cholesterol", "heart health", "hypertension"],
        "source": "https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/fats/fats-in-foods, https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/fats/saturated-fats, https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/fats/fish-and-omega-3-fatty-acids",
        "content": (
            "Not all fats are the same. Dietary fat is a necessary nutrient: it supports cell function, absorbs "
            "fat-soluble vitamins (A, D, E, and K), provides energy, and helps produce hormones. The type of fat "
            "consumed matters far more than the total amount of fat. Replacing harmful fats with beneficial ones is "
            "one of the most impactful dietary changes for heart health.\n\n"
            "Unsaturated fats are the most beneficial type of dietary fat. They are liquid at room temperature and "
            "include two categories. Monounsaturated fats are found in olive oil, avocados, and most nuts (almonds, "
            "cashews, peanuts, pecans). Polyunsaturated fats include omega-3 fatty acids and omega-6 fatty acids. "
            "Omega-3 fatty acids are found in fatty fish (salmon, mackerel, sardines, herring, trout), walnuts, "
            "flaxseed, and chia seeds. Omega-3s reduce inflammation, lower triglycerides, and reduce the risk of "
            "heart disease. The AHA recommends eating fatty fish at least twice per week to obtain omega-3 benefits. "
            "Omega-6 fatty acids are found in vegetable oils such as sunflower, corn, and soybean oil. Both types "
            "of unsaturated fat improve cholesterol levels when they replace saturated fats in the diet.\n\n"
            "Saturated fats are found mainly in animal products including fatty cuts of beef and pork, full-fat dairy "
            "(butter, cream, whole milk, cheese, ice cream), poultry skin, and some plant oils (coconut oil and palm "
            "oil). Eating too much saturated fat raises LDL (bad) cholesterol, which increases the risk of heart attack "
            "and stroke. The AHA recommends limiting saturated fat to less than 6 percent of total daily calories "
            "(about 13 grams on a 2,000-calorie diet) for people with heart disease risk. For reference, one tablespoon "
            "of butter contains about 7 grams of saturated fat.\n\n"
            "Trans fats are the most harmful type of dietary fat and should be avoided entirely. Artificial trans fats "
            "are created when liquid oils are partially hydrogenated (solidified). They raise LDL cholesterol and lower "
            "HDL (good) cholesterol simultaneously, making them more harmful than saturated fat. Trans fats were found "
            "in many packaged snacks, stick margarines, fried fast foods, and commercially baked goods. The FDA banned "
            "partially hydrogenated oils in 2018 in the United States, but small amounts may still be present. Check "
            "ingredient labels for the phrase 'partially hydrogenated oil' to identify remaining trans fat sources.\n\n"
            "Practical fat swaps for daily cooking: use olive oil instead of butter for cooking and salad dressings; "
            "choose avocado instead of cheese on sandwiches; snack on a small handful of nuts instead of chips or "
            "crackers; choose fatty fish such as salmon or sardines twice per week instead of red meat; use hummus "
            "(made from chickpeas and olive oil) instead of mayonnaise or sour cream-based dips. For people managing "
            "hypertension, heart disease, or obesity, these swaps reduce saturated fat intake, increase beneficial "
            "unsaturated fat intake, and lower overall cardiovascular risk without requiring dramatic dietary changes."
        ),
    },
    {
        "id": "sugar_and_sweeteners",
        "title": "Added Sugars, Sugar Limits, and Sweeteners",
        "category": "General",
        "tags": ["sugar", "added sugar", "diabetes", "blood sugar"],
        "source": "https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/sugar/added-sugars, https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/sugar/how-much-sugar-is-too-much, https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/sugar/sugar-101",
        "content": (
            "Added sugars are sugars and syrups that are added to foods or beverages during processing or "
            "preparation, as opposed to naturally occurring sugars found in whole fruits and milk. Added sugars "
            "provide calories but no nutritional value such as vitamins, minerals, or fiber. Consuming too much "
            "added sugar is linked to weight gain, obesity, type 2 diabetes, heart disease, high blood pressure, "
            "fatty liver disease, and tooth decay.\n\n"
            "The AHA recommends that women consume no more than 25 grams (6 teaspoons) of added sugar per day, "
            "and men no more than 36 grams (9 teaspoons) per day. To put this in context, one 12-ounce regular "
            "soda contains about 39 grams of added sugar, which exceeds the daily limit for both men and women in "
            "a single drink. A standard candy bar contains about 20 to 30 grams. A flavored yogurt can contain "
            "15 to 25 grams. Sweetened coffees and teas from coffee shops frequently contain 30 to 60 grams per cup. "
            "Most Americans consume far more than the recommended limit, averaging about 17 teaspoons (68 grams) "
            "of added sugar per day.\n\n"
            "Added sugars appear on ingredient labels under many different names. Common ones include high-fructose "
            "corn syrup (HFCS), cane sugar, beet sugar, brown sugar, corn syrup, dextrose, fructose, glucose, "
            "maltose, sucrose, molasses, honey, maple syrup, agave nectar, and fruit juice concentrate. A useful "
            "rule is that if the word ends in '-ose,' it is a sugar. The Nutrition Facts label now requires a "
            "separate line for Added Sugars (listed under Total Carbohydrates), which makes it easier to identify "
            "products high in added sugar without reading every ingredient.\n\n"
            "Natural sweeteners such as honey, maple syrup, and agave are often perceived as healthier alternatives "
            "to table sugar, but they are still classified as added sugars. They have similar calorie counts and "
            "similar effects on blood sugar. While honey and maple syrup contain trace minerals and antioxidants, "
            "the amounts are too small to provide meaningful health benefits at typical consumption levels. For "
            "people managing diabetes or pre-diabetes, all forms of added sugar, including natural sweeteners, "
            "raise blood glucose and should be limited.\n\n"
            "Artificial sweeteners (aspartame, sucralose, saccharin, acesulfame potassium) and newer sweeteners "
            "(stevia, monk fruit) provide sweet taste with few or no calories and do not raise blood sugar. They "
            "can be useful tools for people with diabetes who want to enjoy sweet flavors without the blood sugar "
            "impact. However, current research suggests they should be used in moderation rather than consumed in "
            "large amounts, and they work best as a transitional tool to help reduce overall sweetness preference "
            "over time rather than as a long-term replacement for whole foods. The Dietary Guidelines for Americans "
            "2025-2030 do not recommend any amount of added sugars or non-nutritive sweeteners as part of a healthy "
            "diet."
        ),
    },
    {
        "id": "food_allergies_overview",
        "title": "Common Food Allergies, Intolerances, and Dietary Restrictions",
        "category": "General",
        "tags": ["food allergies", "diet restrictions", "labels", "nutrition"],
        "source": "https://www.fda.gov/food/nutrition-food-labeling-and-critical-foods/food-allergies, https://www.fda.gov/food/buy-store-serve-safe-food/food-allergies-what-you-need-know",
        "content": (
            "Food allergies and intolerances are common reasons why people avoid certain foods or food groups. "
            "Understanding the difference between the two is important for making safe and appropriate food choices. "
            "A food allergy is an immune system reaction to a specific protein in a food. Even a tiny amount of "
            "the allergen can trigger a reaction ranging from hives, swelling, and stomach pain to anaphylaxis, "
            "which is a severe life-threatening reaction requiring emergency treatment. A food intolerance, by "
            "contrast, is a digestive system response. It does not involve the immune system and is usually not "
            "life-threatening, though it can cause significant discomfort.\n\n"
            "The FDA recognizes 9 major food allergens in the United States that must be declared on food labels. "
            "These are milk, eggs, fish, shellfish (such as shrimp, lobster, and crab), tree nuts (such as almonds, "
            "walnuts, and cashews), peanuts, wheat, soybeans, and sesame (added in 2023). These 9 allergens account "
            "for approximately 90 percent of all food allergic reactions in the United States. Symptoms of an allergic "
            "reaction may include hives, rash, tingling or itching in the mouth, swelling of the lips or throat, "
            "stomach cramps, vomiting, diarrhea, difficulty breathing, and in severe cases, a drop in blood pressure "
            "and loss of consciousness. The only treatment for a food allergy is complete avoidance of the allergen.\n\n"
            "Reading food labels is the most important skill for managing food allergies. In the United States, the "
            "law requires that the 9 major allergens be clearly listed on packaged food labels, either in the ingredient "
            "list or in a separate 'Contains' statement such as 'Contains: milk, wheat, soy.' Cross-contamination "
            "warnings such as 'May contain traces of peanuts' or 'Processed in a facility that also handles tree nuts' "
            "indicate a risk but are voluntary statements. People with severe allergies should treat these warnings "
            "seriously. When eating at restaurants, informing the server of the allergy, asking about ingredients and "
            "preparation methods, and requesting that the kitchen use clean utensils and surfaces is essential.\n\n"
            "Lactose intolerance is the most common food intolerance. It occurs when the body does not produce enough "
            "lactase, the enzyme needed to digest lactose (the natural sugar in milk). Symptoms include bloating, gas, "
            "stomach cramps, and diarrhea within 30 minutes to 2 hours of consuming dairy products. Lactose intolerance "
            "is especially common among people of Asian, African, Hispanic, and Native American descent. Unlike a milk "
            "allergy, lactose intolerance does not involve the immune system and is not dangerous. Many people with "
            "lactose intolerance can tolerate small amounts of dairy, especially hard cheeses (which are low in lactose) "
            "and yogurt (where bacteria break down much of the lactose). Lactose-free milk and plant-based milks fortified "
            "with calcium are good alternatives.\n\n"
            "Gluten sensitivity and celiac disease involve reactions to gluten, a protein found in wheat, barley, and rye. "
            "Celiac disease is an autoimmune condition in which gluten triggers an immune response that damages the small "
            "intestine lining, impairing nutrient absorption. Non-celiac gluten sensitivity causes similar symptoms "
            "without the intestinal damage. Symptoms of both include abdominal pain, bloating, diarrhea, fatigue, and "
            "brain fog. Gluten-free grains and starches include rice, corn, oats (certified gluten-free), quinoa, "
            "buckwheat, millet, potatoes, and tapioca. Hidden sources of gluten include soy sauce, many soups and sauces, "
            "salad dressings, processed meats, and beer. People with celiac disease must follow a strict lifelong "
            "gluten-free diet."
        ),
    },
    {
        "id": "lactose_intolerance",
        "title": "Lactose Intolerance: Managing Dairy and Getting Enough Calcium",
        "category": "General",
        "tags": ["lactose intolerance", "dairy", "calcium", "digestion"],
        "source": "https://www.niddk.nih.gov/health-information/digestive-diseases/lactose-intolerance, https://www.niddk.nih.gov/health-information/digestive-diseases/lactose-intolerance/definition-facts, https://www.niddk.nih.gov/health-information/digestive-diseases/lactose-intolerance/eating-diet-nutrition",
        "content": (
            "Lactose intolerance is a common digestive condition affecting approximately 36 percent of Americans "
            "and up to 70 percent of the global adult population. It occurs when the small intestine does not produce "
            "enough lactase, the enzyme that breaks down lactose (the natural sugar found in milk and dairy products). "
            "Undigested lactose passes into the large intestine, where bacteria ferment it, producing gas and causing "
            "symptoms. Lactose intolerance is not a food allergy and is not dangerous, but it can significantly affect "
            "dietary choices and nutritional intake if not managed carefully.\n\n"
            "Symptoms of lactose intolerance typically appear 30 minutes to 2 hours after consuming dairy and include "
            "bloating, gas, stomach cramps or pain, diarrhea, and nausea. The severity of symptoms varies widely "
            "between individuals and depends on how much lactase the person produces, how much lactose they consumed, "
            "and whether food was eaten at the same time (which slows digestion and reduces symptoms). Many people "
            "with lactose intolerance can tolerate small amounts of dairy, particularly when consumed with other foods.\n\n"
            "Not all dairy products contain the same amount of lactose. Hard aged cheeses such as cheddar, Swiss, "
            "Parmesan, and Gouda are very low in lactose (less than 1 gram per serving) because most of the lactose "
            "is removed during the cheese-making process. Plain yogurt with live bacterial cultures is much lower in "
            "lactose than milk because the bacteria break down a significant portion of the lactose during fermentation. "
            "Regular milk, soft cheeses, ice cream, and cream-based products are highest in lactose. Lactose-free milk "
            "is regular milk treated with the lactase enzyme to pre-digest the lactose; it has the same nutritional "
            "profile as regular milk and is safe for people with lactose intolerance.\n\n"
            "Getting enough calcium is the primary nutritional concern for people managing lactose intolerance. Calcium "
            "is essential for bone health and also plays a role in blood pressure regulation (relevant for people with "
            "hypertension) and muscle function. The daily calcium requirement for adults aged 19 to 50 is 1,000 mg, "
            "and 1,200 mg for women over 50 and men over 70. Non-dairy calcium sources include canned salmon with bones "
            "(about 210 mg per 3 ounces), canned sardines with bones (about 350 mg per 3 ounces), calcium-set tofu "
            "(about 200 to 400 mg per half cup), white beans (about 130 mg per half cup), edamame (about 100 mg per "
            "half cup), kale and bok choy (about 100 mg per cup cooked), broccoli (about 45 mg per cup), and almonds "
            "(about 75 mg per ounce).\n\n"
            "Fortified plant-based milks including soy, almond, oat, and rice milk are widely available and typically "
            "fortified with 300 to 450 mg of calcium per cup, comparable to cow's milk. Vitamin D is added to most "
            "fortified plant milks as well, which is important because vitamin D is needed for calcium absorption. "
            "Soy milk has the highest protein content among plant milks and most closely matches the nutritional profile "
            "of cow's milk. Lactase enzyme supplements taken before eating dairy allow some people with lactose "
            "intolerance to consume dairy products without symptoms, though the effectiveness varies by individual."
        ),
    },
    {
        "id": "healthy_cooking_methods",
        "title": "Healthy Cooking Methods and Kitchen Substitutions",
        "category": "General",
        "tags": ["cooking", "low fat", "low sodium", "healthy eating"],
        "source": "https://www.heart.org/en/healthy-living/healthy-eating/cooking-skills/cooking/techniques/healthy-cooking-methods, https://www.heart.org/en/healthy-living/healthy-eating/cooking-skills/cooking/how-to-cook-healthier-at-home, https://www.myplate.gov/eat-healthy/healthy-eating-budget/prepare-healthy-meals",
        "content": (
            "How food is prepared has as much impact on its healthiness as what food is chosen. The same chicken "
            "breast can be a lean, heart-healthy protein when baked, or a calorie-dense, high-sodium food when "
            "breaded and deep-fried. Learning a few cooking methods and ingredient swaps allows anyone to prepare "
            "nutritious, satisfying meals regardless of budget, equipment, or cooking skill level.\n\n"
            "The healthiest cooking methods preserve nutrients, add minimal fat, and avoid creating harmful compounds. "
            "Baking or roasting uses dry heat in an oven and works well for vegetables, fish, poultry, and lean meats. "
            "Roasting vegetables at 400 to 425 degrees Fahrenheit with a light drizzle of olive oil concentrates flavor "
            "and requires little preparation. Grilling or broiling uses direct high heat and allows fat to drip away from "
            "meat. Steaming uses water vapor to cook food and is one of the gentlest methods, preserving the most "
            "water-soluble vitamins and minerals. It works especially well for vegetables and fish. Stir-frying uses a "
            "small amount of oil in a hot pan with constant motion, allowing food to cook quickly while retaining texture "
            "and nutrients. Poaching and simmering involve cooking food in liquid at low heat and work well for eggs, fish, "
            "and chicken.\n\n"
            "Deep-frying adds significant amounts of fat and calories and should be avoided or used very sparingly. "
            "Even air-frying (which circulates hot air to mimic frying with little or no oil) produces results similar "
            "in texture to deep-frying with substantially less fat. Air-frying is a practical option for households that "
            "enjoy crispy textures and have access to this appliance. Pan-frying with a small amount of oil in a non-stick "
            "skillet is also a lower-fat alternative to deep-frying.\n\n"
            "Healthy ingredient substitutions allow favorite recipes to be made more nutritious without sacrificing flavor. "
            "Olive oil can replace butter in most savory cooking, saving saturated fat. Plain Greek yogurt can replace sour "
            "cream or mayonnaise in dips, dressings, and toppings, providing protein and reducing saturated fat. Unsweetened "
            "applesauce can replace oil in baked goods such as muffins and quick breads, reducing fat and calories. Mashed "
            "ripe banana can replace added sugar in baked goods, adding potassium and fiber. Herbs, spices, lemon juice, and "
            "vinegar can replace salt for flavor, significantly reducing sodium in homemade meals. Whole wheat flour can "
            "replace up to half of all-purpose white flour in baking, adding fiber and nutrients without significantly "
            "changing texture.\n\n"
            "Using herbs and spices effectively is one of the most impactful skills for reducing sodium in home cooking. "
            "Garlic (fresh, powdered, or roasted) adds depth to nearly any savory dish. Onion, shallots, and scallions "
            "provide flavor foundations. Cumin, coriander, and turmeric work well in soups, stews, and grain dishes. "
            "Rosemary, thyme, and oregano enhance roasted meats and vegetables. Chili powder, smoked paprika, and cayenne "
            "add warmth and complexity without sodium. Lemon or lime juice brightens flavor at the end of cooking and can "
            "reduce the perceived need for salt. Black pepper enhances other flavors. Building a pantry of these ingredients "
            "makes it much easier to cook flavorful, low-sodium meals at home."
        ),
    },
    {
        "id": "diabetes_plate_method",
        "title": "Diabetes Plate Method for Blood Sugar Control",
        "category": "Diabetes",
        "tags": ["diabetes", "blood sugar", "nutrition", "diabetes plate"],
        "source": "Diabetes Plate Plan",
        "content": (
            "The diabetes plate method is a simple and balanced way to build meals that help control blood sugar. "
            "Half of the plate should be filled with non-starchy vegetables such as broccoli, carrots, leafy greens, tomatoes, cauliflower, and zucchini. "
            "These foods are low in carbohydrates and high in fiber, which helps keep blood sugar stable.\n\n"
            "One quarter of the plate should include lean protein such as chicken, turkey, fish, eggs, tofu, beans, or lentils. "
            "Protein helps you feel full and supports muscle health. Some plant-based protein foods like beans also contain carbohydrates, so portion control is important.\n\n"
            "The remaining quarter should include healthy carbohydrates such as whole grains like brown rice or oats, starchy vegetables like sweet potatoes or corn, "
            "fruits, and low-fat dairy. These foods have the biggest impact on blood sugar, so choosing high-fiber options helps slow digestion and prevent spikes.\n\n"
            "Water is the best drink choice because it has no calories and does not affect blood sugar. Other good options include unsweetened tea, coffee, or sparkling water. "
            "Limiting sugary drinks and processed foods supports better blood sugar control and overall health."
        ),
    },
    {
        "id": "portion_control_hand_method",
        "title": "Hand Portion Guide for Diabetes Plate Meal Planning",
        "category": "Diabetes",
        "tags": ["nutrition", "weight", "portion size", "diabetes plate"],
        "source": "Diabetes Plate Plan",
        "content": (
            "Portion control is an important part of managing weight and supporting healthy eating habits. "
            "A simple way to estimate portion sizes is by using your hands, which makes it easy to follow even without measuring tools.\n\n"
            "The palm of your hand represents about three ounces of protein such as meat, poultry, or fish. "
            "Your fist represents about one cup, which can be used for fruits, vegetables, or dairy. "
            "A cupped hand represents about half a cup, which is useful for grains, beans, or snacks like nuts.\n\n"
            "The tip of your thumb represents about one tablespoon, which can be used for foods like peanut butter or salad dressing. "
            "The tip of your finger represents about one teaspoon. These simple measurements help control portions and prevent overeating.\n\n"
            "Using hand-based portion control makes it easier to build balanced meals, manage calorie intake, and support weight control over time."
        ),
    },
    {
        "id": "dash_diet_plan",
        "title": "DASH Diet for Blood Pressure Control",
        "category": "Hypertension",
        "tags": ["hypertension", "blood pressure", "nutrition"],
        "source": "DASH Diet Plan",
        "content": (
            "The DASH diet, which stands for Dietary Approaches to Stop Hypertension, is a long-term eating plan designed to lower blood pressure and support overall health. "
            "It focuses on eating whole, nutrient-rich foods such as fruits, vegetables, whole grains, lean proteins, and low-fat dairy.\n\n"
            "This eating pattern encourages reducing sodium, added sugars, and unhealthy fats. Limiting processed and packaged foods is important because they are often high in salt, "
            "which can raise blood pressure. Sodium intake should be limited to about 1,500 milligrams per day to help lower blood pressure. "
            "At the same time, the diet promotes foods rich in potassium such as fruits, vegetables, beans, and dairy, which help balance sodium levels and support healthy blood pressure.\n\n"
            "A typical daily plan includes grains, vegetables, fruits, low-fat dairy, and lean proteins such as poultry or fish. It also includes small amounts of healthy fats like olive oil, "
            "along with nuts, seeds, and legumes throughout the week. Sweets and sugary drinks should be limited.\n\n"
            "The DASH diet also supports weight management and can improve blood sugar control. By focusing on whole foods and balanced meals, it helps reduce the risk of chronic conditions "
            "and supports long-term heart health."
        ),
    },
    {
        "id": "dash_diet_portions",
        "title": "DASH Diet Serving Sizes and Portion Guide",
        "category": "Hypertension",
        "tags": ["hypertension", "nutrition", "weight", "dash diet", "portion size"],
        "source": "DASH Diet Plan",
        "content": (
            "The DASH diet provides clear guidelines on how much to eat from each food group to help manage blood pressure and maintain a healthy weight. "
            "For a typical 2,000 calorie plan, it is recommended to eat 6 to 8 servings of grains, 4 to 5 servings of vegetables, and 4 to 5 servings of fruits each day.\n\n"
            "Low-fat or fat-free dairy should be consumed 2 to 3 times daily, while lean meats, poultry, or fish should be limited to 6 servings or less per day. "
            "Healthy fats and oils should be used in small amounts, about 2 to 3 servings per day. Nuts, seeds, and legumes should be included about 4 to 5 servings per week, "
            "while sweets should be limited to no more than 5 servings per week.\n\n"
            "Serving sizes can be estimated using simple visual cues. A serving of grains or fruit is about the size of a fist. A cup of vegetables is about the size of two hands. "
            "Three ounces of cooked meat is about the size of the palm of your hand. A cupped hand represents about half a cup, which can be used for grains, beans, or snacks.\n\n"
            "Sodium intake should be limited to about 1,500 milligrams per day to help lower blood pressure. Choosing fresh foods and low-sodium options can help reduce salt intake. "
            "Following these portion guidelines makes it easier to control blood pressure, support weight management, and maintain overall health."
        ),
    },
    {
        "id": "myplate_meal_planning",
        "title": "MyPlate for Balanced Meal Planning",
        "category": "Obesity",
        "tags": ["nutrition", "balanced diet", "weight", "blood sugar", "MyPlate"],
        "source": "MyPlate Plan",
        "content": (
            "MyPlate is a simple guide that helps you build balanced meals using the main food groups in the right proportions. "
            "It includes fruits, vegetables, whole grains, protein foods, and low-fat dairy, and is designed to be flexible and easy to follow.\n\n"
            "Fruits and vegetables should make up a large part of your plate. Fruits can be fresh, frozen, canned, or dried, but whole fruits are the best choice. "
            "Vegetables can be added to meals such as casseroles, wraps, and sandwiches. These foods provide fiber and nutrients "
            "that help control blood sugar, support weight management, and improve overall health.\n\n"
            "Grains should mostly be whole grains such as whole wheat bread, brown rice, and oatmeal. Whole grains contain more fiber and help keep blood sugar stable. "
            "Protein foods include beans, lentils, seafood, poultry, eggs, nuts, and seeds. Choosing lean and plant-based options more often supports heart health and weight control.\n\n"
            "Low-fat or fat-free dairy foods such as milk, yogurt, or fortified plant-based alternatives provide calcium and important nutrients. "
            "Limiting added sugars, saturated fat, and sodium is also important for maintaining healthy blood pressure and weight.\n\n"
            "To support overall health, limit added sugars, saturated fat, and sodium, and aim for regular physical activity such as about 150 minutes per week.\n\n"
            "MyPlate encourages balanced eating habits that support weight management, improve blood sugar control, and promote long-term health."
        ),
    },
    {
        "id": "myplate_portion_guide",
        "title": "MyPlate Portion Size and Serving Guide",
        "category": "Obesity",
        "tags": ["portion control", "weight", "nutrition", "MyPlate", "portion size"],
        "source": "MyPlate Plan",
        "content": (
            "Portion control is an important part of building balanced meals and managing weight. A simple way to estimate portion sizes is by using your hands, "
            "which makes it easy to follow without measuring tools.\n\n"
            "The palm of your hand represents about three ounces of protein such as meat, poultry, or fish. "
            "Your fist represents about one cup, which can be used for fruits, vegetables, or dairy foods. "
            "A cupped hand represents about half a cup, which works well for grains, beans, or snacks like nuts.\n\n"
            "The tip of your thumb represents about one tablespoon, which can be used for foods like peanut butter or salad dressing. "
            "The tip of your finger represents about one teaspoon. These simple estimates help control portion sizes and prevent overeating.\n\n"
            "Using portion control along with balanced food choices helps manage calorie intake, supports weight control, and improves blood sugar and blood pressure over time."
        ),
    },
    {
        "id": "fiber_guide",
        "title": "High Fiber Eating for Weight, Blood Sugar, and Blood Pressure Control",
        "category": "General",
        "tags": ["fiber", "weight", "diabetes"],
        "source": "FPL Fiber Guide",
        "content": (
            "The Full Plate approach focuses on filling about 75 percent of each meal with whole, unprocessed foods "
            "such as fruits, vegetables, beans, and whole grains. These foods are high in fiber and water, which help you feel "
            "full without adding extra calories. This makes it easier to manage weight and prevent obesity. Many people eat far "
            "less fiber than they need, so increasing fiber intake can support better digestion and improve overall health. "
            "It can also help lower blood sugar levels and reduce the risk of high blood pressure.\n\n"
            "Foods like beans, whole grains, fruits, and vegetables are especially helpful because they slow down digestion. "
            "This helps prevent sudden increases in blood sugar, which is important for people with diabetes or prediabetes. "
            "Fiber also supports heart health by helping lower unhealthy fat levels in the blood and improving blood pressure. "
            "Drinking enough water is important when increasing fiber intake because it helps the body process fiber more easily "
            "and prevents discomfort.\n\nTo get the most benefit, it is important to limit high-calorie additions such as butter, cheese, "
            "and sugary sauces. These foods can reduce the positive effects of healthy meals and make it harder to control weight. "
            "Some processed foods may contain fiber, but they are often higher in calories and should be eaten in smaller amounts. "
            "Focusing on whole, plant-based foods most of the time helps build healthy eating habits that support weight control, better "
            "blood sugar levels, and improved blood pressure over time."
        ),
    },
    {
        "id": "full_plate_living",
        "title": "Full Plate Eating Approach for Healthy Weight and Blood Sugar Control",
        "category": "Obesity",
        "tags": ["fiber", "weight", "diabetes"],
        "source": "Full Plate Living Program",
        "content": (
            "The Full Plate Living program encourages a simple way of eating that supports weight control and long-term health. "
            "It recommends filling about 75 percent of each meal with whole foods such as fruits, vegetables, beans, and whole grains, while "
            "keeping the remaining portion for other foods. These fiber-rich foods help you feel full while eating fewer calories, which makes it "
            "easier to manage weight without feeling hungry. Many people do not eat enough fiber, so increasing fiber intake can improve digestion "
            "and support better control of blood sugar and blood pressure.\n\n"
            "Eating more fiber-rich foods can help lower blood sugar levels by slowing digestion and reducing sudden spikes. This is especially helpful "
            "for people with diabetes or prediabetes. These foods can also help lower unhealthy fat levels in the blood and support better heart health. "
            "Drinking enough water each day helps the body adjust to higher fiber intake and supports digestion. It is also helpful to increase fiber "
            "slowly to avoid discomfort.\n\nThe program encourages simple habits such as adding more fiber foods to meals and eating them first to feel "
            "full sooner. It also suggests limiting sugary drinks and highly processed foods, as these can lead to weight gain and poor blood sugar control. "
            "Building small, realistic habits over time makes it easier to maintain healthy eating patterns. This approach supports steady weight loss, "
            "better blood sugar control, and improved blood pressure in a way that is practical and sustainable."
        ),
    },
    {
        "id": "full_plate_diet",
        "title": "Fiber-Based Diet for Weight Loss and Blood Sugar Control",
        "category": "Obesity",
        "tags": ["fiber", "weight", "diabetes"],
        "source": "Full Plate Diet Book",
        "content": (
            "The Full Plate Diet is based on the idea that eating more fiber-rich foods can support weight loss and improve overall health. "
            "Foods such as fruits, vegetables, beans, whole grains, nuts, and seeds are high in fiber and help you feel full for longer periods. This can "
            "reduce how much you eat without needing strict portion control. Many people eat too little fiber, so increasing intake can help with weight "
            "management and support better control of blood sugar and blood pressure.\n\n"
            "Fiber plays an important role in slowing digestion. This helps prevent quick rises in blood sugar, which is important for people with diabetes "
            "or prediabetes. It also helps lower unhealthy fat levels in the blood and supports heart health. Choosing whole foods instead of processed foods "
            "is important because processed foods are often low in fiber and high in calories, which can lead to weight gain and poor health outcomes.\n\n"
            "The diet also encourages limiting sugary drinks and refined foods such as white bread and packaged snacks. These foods do not keep you full and "
            "can cause rapid increases in blood sugar. Instead, focusing on whole plant foods provides steady energy and important nutrients. Drinking enough "
            "water and increasing fiber slowly can help the body adjust. This approach makes it easier to build healthy eating habits that support weight control, "
            "stable blood sugar levels, and better blood pressure over time."
        ),
    },
    {
        "id": "grocery_shopping_guide",
        "title": "Smart Grocery Shopping for Healthy Eating and Weight Control",
        "category": "General",
        "tags": ["nutrition", "weight", "diabetes"],
        "source": "Finding Water-Fiber Foods at the Store",
        "content": (
            "Choosing the right foods at the grocery store can make a big difference in managing weight, blood sugar, and blood pressure. The best approach "
            "is to focus on whole, plant-based foods that are high in fiber and water. These include fruits, vegetables, beans, and whole grains. These foods help you "
            "feel full while providing important nutrients, which supports weight control and overall health.\n\n"
            "The fresh produce section is a good place to start. Foods like apples, oranges, leafy greens, carrots, and broccoli are rich in fiber and help keep blood "
            "sugar stable. Frozen fruits and vegetables are also a good option because they provide the same benefits and can be more convenient. In the canned food section, "
            "beans and vegetables can be healthy choices if you select low-sodium options. Rinsing canned beans can help reduce salt content.\n\n"
            "Whole grains such as oats and brown rice are better choices than refined grains because they contain more fiber and help control blood sugar. On the other hand, "
            "foods like chips, cookies, sugary drinks, and refined snacks are low in fiber and high in calories. These foods can lead to weight gain and poor blood sugar control "
            "and should be limited.\n\n"
            "A simple way to make better choices is to ask whether a food is a fruit, vegetable, bean, or whole grain. If it is, it is likely a healthy option. Focusing on these "
            "foods helps build meals that support weight management, stable blood sugar, and better blood pressure."
        ),
    },
    {
        "id": "natural_fiber_foods",
        "title": "Types of Fiber Foods and Their Benefits for Health",
        "category": "General",
        "tags": ["fiber", "nutrition", "weight"],
        "source": "Natural Fiber Food Inventory",
        "content": (
            "Natural fiber foods come from several groups, including fruits, vegetables, beans, whole grains, nuts, and seeds. These foods play an important "
            "role in building a healthy diet that supports weight control and helps manage blood sugar and blood pressure. They are rich in nutrients and help the body "
            "function properly while also helping you feel full with fewer calories.\n\n"
            "Fruits provide natural sweetness along with fiber, water, and important nutrients. They can help satisfy cravings while supporting better blood sugar control "
            "when eaten in whole form. Vegetables are especially helpful because they are low in calories but high in fiber and nutrients, making them a key part of meals "
            "for weight management and overall health.\n\n"
            "Beans and legumes are unique because they provide both fiber and plant-based protein. They help you feel full, support muscle health, and help keep blood sugar "
            "stable. Whole grains such as oats and brown rice are better than refined grains because they contain more fiber and digest more slowly, which helps prevent sudden "
            "increases in blood sugar.\n\n"
            "Nuts and seeds also contain fiber but are higher in calories, so they should be eaten in smaller portions. Choosing whole, unprocessed foods from these groups helps "
            "support digestion, control blood sugar, and improve blood pressure. Making these foods a regular part of meals can help prevent and manage conditions such as obesity, "
            "diabetes, and high blood pressure."
        ),
    },
    {
        "id": "motivational_interviewing",
        "title": "Building Healthy Habits for Weight and Blood Sugar Control",
        "category": "General",
        "tags": ["stress", "weight", "diabetes"],
        "source": "Motivational Interviewing",
        "content": (
            "Motivational Interviewing is a simple and supportive way to help people make healthy changes in their eating and lifestyle habits. Instead of telling "
            "people what to do, it focuses on helping them find their own reasons to change. This approach is useful for improving habits related to weight management, blood sugar "
            "control, and blood pressure. It works by building confidence and helping people take small, realistic steps toward better health.\n\n"
            "The first step is to create a safe and respectful environment where people feel comfortable sharing their thoughts and challenges. Many unhealthy eating habits are "
            "linked to stress, convenience, or emotions, so it is important to understand the reasons behind these behaviors. The next step is to help the person see the gap between "
            "their current habits and their health goals. For example, someone may want to control their blood sugar but struggle with sugary foods.\n\n"
            "The approach then focuses on helping people discover their own motivation. When individuals understand why change matters to them, they are more likely to take action. "
            "Simple questions about readiness and confidence can help identify what is holding them back. The final step is to create a clear and realistic plan. This includes setting "
            "small goals such as adding more vegetables to meals or reducing sugary drinks.\n\n"
            "This method supports long-term success because it focuses on progress rather than perfection. It helps people build healthy habits step by step, which can improve weight control, "
            "support better blood sugar levels, and help manage blood pressure over time."
        ),
    },
    {
        "id": "type2_diabetes_management",
        "title": "Meal Planning and Food Choices for Type 2 Diabetes",
        "category": "Diabetes",
        "tags": ["diabetes", "blood sugar", "weight"],
        "source": "T2 Participants",
        "content": (
            "Managing prediabetes and type 2 diabetes requires making consistent food and lifestyle choices that support stable blood sugar levels and a healthy weight. "
            "A simple and effective way to plan meals is to use a plate method. Half of the plate should include non-starchy vegetables such as leafy greens, broccoli, and peppers. "
            "One quarter should include whole grains or starchy foods like brown rice or sweet potatoes. The remaining quarter should include lean protein such as fish, poultry, or beans. "
            "This balance helps control portions and supports better blood sugar control.\n\n"
            "Carbohydrates have the strongest effect on blood sugar, so choosing the right type is important. Foods high in fiber, such as whole grains, fruits, and vegetables, are digested "
            "more slowly and help prevent sudden increases in blood sugar. Refined foods such as white bread and sugary snacks can cause quick spikes in blood sugar and should be limited. "
            "Increasing fiber intake also helps improve digestion and supports weight management.\n\n"
            "Healthy fats from foods such as nuts, seeds, and plant oils can support heart health, while unhealthy fats from processed foods and fatty meats should be limited. Reducing salt "
            "intake can also help control blood pressure, which is important for people with diabetes.\n\n"
            "In addition to healthy eating, regular physical activity and modest weight loss can greatly improve blood sugar control. Even small changes, such as walking regularly and choosing "
            "whole foods, can reduce the risk of developing diabetes or help manage the condition more effectively over time."
        ),
    },
    {
        "id": "dash_blood_pressure",
        "title": "DASH Eating Plan for High Blood Pressure Control",
        "category": "Hypertension",
        "tags": ["blood pressure", "hypertension", "nutrition"],
        "source": "Lowering Blood Pressure with DASH",
        "content": (
            "The DASH eating plan is designed to help lower blood pressure and improve heart health through simple and balanced food choices. It focuses on eating more fruits, vegetables, "
            "whole grains, lean proteins, and low-fat dairy while reducing salt, added sugars, and unhealthy fats. This combination of foods provides important nutrients that help the body control blood "
            "pressure naturally.\n\n"
            "One of the key parts of the DASH plan is reducing sodium intake. Most people consume too much salt from processed and packaged foods, which can raise blood pressure. By choosing fresh foods "
            "and limiting processed items, it becomes easier to reduce sodium levels. At the same time, eating foods rich in potassium, such as fruits and vegetables, helps balance sodium in the body and "
            "supports healthy blood pressure.\n\n"
            "The DASH plan also encourages replacing high-fat and processed foods with healthier options. Choosing whole grains instead of refined grains and lean protein instead of fatty meats helps support "
            "weight management and overall health. These changes can also improve blood sugar control, which is important for people with diabetes or prediabetes.\n\n"
            "This eating pattern is flexible and easy to follow, making it suitable for long-term use. By focusing on simple changes such as eating more plant-based foods and reducing salt, individuals can "
            "improve blood pressure, support weight control, and reduce the risk of chronic health problems."
        ),
    },
    {
        "id": "lifestyle_nutrition",
        "title": "Healthy Eating Habits for Long-Term Weight and Blood Sugar Control",
        "category": "Diabetes",
        "tags": ["nutrition", "weight", "diabetes"],
        "source": "Patient LM Nutrition",
        "content": (
            "Lifestyle nutrition focuses on using food as a tool to improve health and prevent disease. It encourages eating whole, plant-based foods such as fruits, vegetables, whole grains, beans, "
            "nuts, and seeds. These foods are rich in nutrients and fiber, which help support weight management, control blood sugar, and improve blood pressure.\n\n"
            "Whole foods provide important nutrients that help the body function properly. They support digestion, improve energy levels, and help reduce inflammation in the body. In contrast, processed foods "
            "such as sugary drinks, packaged snacks, and high-fat foods can lead to weight gain and poor control of blood sugar and blood pressure. Limiting these foods is important for maintaining good health.\n\n"
            "Making small and realistic changes is key to building lasting habits. Instead of trying to change everything at once, it is more effective to set simple goals, such as adding more fruits and vegetables "
            "to meals or reducing sugary drinks. These small steps can lead to steady improvements over time.\n\n"
            "This approach helps people take control of their health by focusing on daily habits. Eating more whole foods and reducing processed foods can support weight control, improve blood sugar levels, and help "
            "manage blood pressure in a sustainable way."
        ),
    },
    {
        "id": "nutrition_myths",
        "title": "Common Nutrition Myths and Healthy Food Choices",
        "category": "General",
        "tags": ["nutrition", "weight", "diabetes"],
        "source": "Nutrition Myths",
        "content": (
            "Many common beliefs about nutrition can make it harder for people to make healthy choices. One common myth is that people need animal products to get enough protein. In reality, plant-based "
            "foods such as beans, lentils, nuts, and whole grains provide enough protein along with fiber and other important nutrients. These foods can support weight management and help control blood sugar and blood pressure.\n\n"
            "Another common belief is that dairy is the only way to get enough calcium. However, many plant foods such as leafy greens and fortified products also provide calcium and support bone health. Choosing a variety of whole foods "
            "can help meet nutrient needs without relying on a single food group.\n\n"
            "A third myth is that carbohydrates are always unhealthy. The truth is that the type of carbohydrate matters. Whole carbohydrates found in fruits, vegetables, and whole grains provide fiber and steady energy. These foods help "
            "keep blood sugar stable and support overall health. Refined carbohydrates such as white bread and sugary snacks can cause quick increases in blood sugar and should be limited.\n\n"
            "Understanding these differences helps people make better food choices. Focusing on whole, plant-based foods instead of processed foods can support weight control, improve blood sugar levels, and help manage blood pressure over time."
        ),
    },
    {
        "id": "diabetes_lifestyle_pillars",
        "title": "Lifestyle Habits for Managing Type 2 Diabetes",
        "category": "Diabetes",
        "tags": ["diabetes", "weight", "exercise"],
        "source": "Lifestyle Pillars for Type 2 Diabetes",
        "content": (
            "Managing and preventing type 2 diabetes requires a combination of healthy habits that work together to improve blood sugar control and support a healthy weight. One of the most important steps is following a balanced eating "
            "pattern that focuses on whole foods such as vegetables, fruits, whole grains, beans, nuts, and seeds. These foods provide fiber and nutrients that help control blood sugar and reduce hunger. A simple way to build meals is to fill half "
            "the plate with non-starchy vegetables, one quarter with whole grains or starchy foods, and one quarter with protein such as beans or lean sources.\n\n"
            "Physical activity plays a key role in improving how the body uses sugar. Regular movement helps lower blood sugar levels and supports weight management. Even light activity after meals, such as walking, can reduce blood sugar spikes. "
            "Getting enough sleep is also important, as poor sleep can make it harder to control blood sugar and increase hunger.\n\n"
            "Stress can affect eating habits and blood sugar levels, so managing stress is important. Simple practices such as deep breathing, relaxation, and staying connected with others can help reduce stress. Building strong support systems with "
            "family or community can also make it easier to maintain healthy habits.\n\nThese lifestyle changes work best when practiced together. Eating well, staying active, sleeping enough, and managing stress all support better blood sugar control "
            "and long-term health. Small and consistent changes can lead to lasting improvements in managing diabetes and maintaining a healthy weight."
        ),
    },
    {
        "id": "sleep_health",
        "title": "How Sleep Affects Weight, Blood Sugar, and Blood Pressure",
        "category": "Sleep",
        "tags": ["sleep", "diabetes", "weight"],
        "source": "Sleep Guide",
        "content": (
            "Sleep plays an important role in maintaining good health, especially for managing weight, blood sugar, and blood pressure. Most adults need about seven to nine hours of sleep each night. When people do not get enough sleep, "
            "they may feel tired, have trouble focusing, and make less healthy food choices. Poor sleep can also increase hunger and make it harder to feel full, which can lead to weight gain.\n\n"
            "Lack of sleep can affect how the body controls blood sugar. It can make the body less sensitive to insulin, which can lead to higher blood sugar levels. This is especially important for people with diabetes or prediabetes. Poor sleep "
            "can also raise blood pressure over time, increasing the risk of heart-related problems.\n\n"
            "There are many ways to improve sleep quality. Going to bed and waking up at the same time each day helps the body follow a regular routine. Limiting screen time before bed and reducing caffeine intake can also improve sleep. Creating a "
            "quiet and comfortable sleep environment can make it easier to fall and stay asleep.\n\nHealthy habits such as regular physical activity and balanced eating can also support better sleep. Making small changes, such as setting a regular "
            "bedtime or avoiding late meals, can lead to better sleep over time. Good sleep supports better control of blood sugar, helps manage weight, and improves overall health."
        ),
    },
    {
        "id": "stress_management",
        "title": "Managing Stress for Better Weight and Blood Pressure Control",
        "category": "General",
        "tags": ["stress", "blood pressure", "weight"],
        "source": "Stress Management Guide",
        "content": (
            "Stress can have a strong impact on health, especially when it is ongoing. It can affect eating habits, increase cravings for unhealthy foods, and make it harder to maintain a healthy routine. Stress can also raise blood pressure "
            "and affect blood sugar levels, which is important for people managing diabetes or trying to prevent it.\n\n"
            "When people are stressed, the body releases hormones that can increase hunger and lead to overeating. This can make weight management more difficult. Stress can also reduce motivation to exercise or prepare healthy meals, leading to habits "
            "that negatively affect health over time.\n\n"
            "Managing stress is an important part of maintaining healthy habits. Simple activities such as deep breathing, meditation, listening to music, or spending time with others can help reduce stress. Physical activity is also helpful because it "
            "improves mood and supports overall health.\n\nIt is important to recognize personal stress triggers and find ways to respond in a healthy way. Building small daily habits to manage stress can make a big difference over time. Reducing stress "
            "helps improve eating habits, supports better blood sugar control, and helps maintain healthy blood pressure and weight."
        ),
    },
    {
        "id": "physical_activity",
        "title": "Physical Activity for Weight, Blood Sugar, and Heart Health",
        "category": "Exercise",
        "tags": ["exercise", "weight", "diabetes"],
        "source": "Physical Activity Guide",
        "content": (
            "Regular physical activity is one of the most effective ways to improve health and manage conditions such as diabetes, high blood pressure, and obesity. Being active helps the body use blood sugar more effectively, which can lower "
            "blood sugar levels and improve insulin function. It also helps control weight by burning calories and improving metabolism.\n\n"
            "Adults should aim for regular movement throughout the week. Activities such as walking, cycling, or light sports can improve heart health and support weight management. Strength exercises, such as lifting weights or using body weight, help build "
            "muscle and improve overall strength. Muscle plays an important role in controlling blood sugar, so building and maintaining muscle is beneficial.\n\n"
            "Even small amounts of activity can make a difference. Breaking up long periods of sitting with short walks or movement can help improve blood sugar levels. Choosing activities that are enjoyable makes it easier to stay consistent over time.\n\n"
            "Physical activity also supports better sleep and helps reduce stress, which further improves overall health. Making activity a regular part of daily life can lead to better control of blood sugar, improved blood pressure, and healthier weight management over time."
        ),
    },
    {
        "id": "dash_diet_overview",
        "title": "DASH Diet for Blood Pressure Control",
        "category": "Hypertension",
        "tags": ["hypertension", "blood pressure", "nutrition"],
        "source": "Diet Plan Video",
        "content": (
            "The DASH diet is designed to help lower blood pressure by focusing on balanced and healthy eating habits. "
            "It encourages eating more fruits, vegetables, whole grains, and low-fat dairy while reducing salt, processed foods, and unhealthy fats.\n\n"
            "Reducing sodium intake is one of the most important steps in managing blood pressure. Many packaged and processed foods contain high amounts of salt, "
            "so choosing fresh and whole foods can help lower daily sodium intake. Foods rich in potassium, such as fruits and vegetables, help balance sodium levels "
            "and support healthy blood pressure.\n\n"
            "This eating pattern also supports weight management and helps improve blood sugar control. By focusing on whole foods and limiting processed foods, "
            "the DASH diet helps reduce the risk of chronic conditions and supports long-term heart health."
        ),
    },
    {
        "id": "diabetes_plate_method",
        "title": "Diabetes Plate for Managing Blood Sugar",
        "category": "Diabetes",
        "tags": ["diabetes", "blood sugar", "nutrition"],
        "source": "Diet Plan Video",
        "content": (
            "The plate method is a simple way to manage blood sugar levels by balancing food portions. Half of the plate should be filled with non-starchy vegetables "
            "such as leafy greens, broccoli, and peppers. One quarter should include lean protein such as beans, fish, or chicken, and the remaining quarter should include "
            "whole grains or starchy foods.\n\n"
            "This method helps control portion sizes and prevents sudden increases in blood sugar. Foods high in fiber, such as vegetables and whole grains, are digested more slowly, "
            "which helps maintain stable blood sugar levels.\n\n"
            "Choosing whole foods and limiting sugary and processed foods is important for managing diabetes. This approach also supports weight control and can help reduce the risk of complications."
        ),
    },
    {
        "id": "myplate_balanced_eating",
        "title": "MyPlate Approach for Balanced and Healthy Eating",
        "category": "Obesity",
        "tags": ["nutrition", "weight", "obesity"],
        "source": "Diet Plan Video",
        "content": (
            "MyPlate is a simple guide to building balanced meals that support overall health and weight management. It encourages filling half the plate with fruits and vegetables, "
            "one quarter with whole grains, and one quarter with protein foods.\n\n"
            "This approach helps control portion sizes and ensures a balance of nutrients. Choosing whole grains instead of refined grains and including a variety of fruits and vegetables "
            "can improve digestion and help maintain a healthy weight.\n\n"
            "Limiting added sugars, unhealthy fats, and processed foods is important for preventing weight gain and supporting long-term health. Following MyPlate regularly can help build healthy eating habits."
        ),
    },
    {
        "id": "obesity_mindful_eating",
        "title": "Mindful Eating: How Paying Attention to Food Helps with Weight Management",
        "category": "Obesity",
        "tags": ["mindful eating", "weight management", "eating habits", "portion control", "hunger cues", "obesity"],
        "source": "https://www.niddk.nih.gov/health-information/weight-management/changing-habits-better-health",
        "content": (
            "Mindful eating means paying full attention to what you eat, how much you eat, and how your body "
            "feels before, during, and after eating. It is not a diet. It is a way of relating to food that "
            "helps you make better choices without strict rules or calorie counting.\n\n"
            "Many people eat for reasons other than hunger — stress, boredom, habit, or emotions. This is "
            "called emotional or mindless eating. When you eat without thinking, it is easy to eat more than "
            "your body needs. Over time, this can contribute to weight gain. Mindful eating helps break this "
            "pattern by slowing down the eating process and helping you notice when you are truly hungry and "
            "when you are full.\n\n"
            "Key practices in mindful eating include: eating slowly without distractions like phones or "
            "television; paying attention to the taste, texture, and smell of food; stopping to check in on "
            "hunger and fullness levels during the meal; eating only until you feel comfortably full, not "
            "stuffed; and recognizing emotional triggers that lead to eating when you are not physically hungry.\n\n"
            "Research shows that people who eat more slowly tend to eat fewer calories and feel more satisfied "
            "after meals. It takes about 20 minutes for the stomach to signal fullness to the brain. Eating "
            "too quickly means you may eat well past the point of fullness before that signal arrives.\n\n"
            "Practical steps to eat more mindfully: use a smaller plate to help with portion sizes; sit down "
            "at a table for every meal; put down your fork between bites; chew each bite thoroughly; avoid "
            "eating straight from a bag or container; and plan meals ahead of time so you are not eating "
            "impulsively when very hungry.\n\n"
            "Mindful eating does not require eliminating any food group. It helps you enjoy food more and "
            "naturally eat less by tuning in to your body's real signals. For people managing obesity or "
            "working toward a healthier weight, mindful eating is a practical, sustainable habit that "
            "supports long-term change without the restriction and deprivation of traditional dieting."
        ),
    },
    {
        "id": "hypertension_potassium_foods",
        "title": "Potassium-Rich Foods That Help Lower Blood Pressure",
        "category": "Hypertension",
        "tags": ["potassium", "blood pressure", "hypertension", "fruits", "vegetables", "DASH", "sodium", "heart health"],
        "source": "https://www.heart.org/en/health-topics/high-blood-pressure/changes-you-can-make-to-manage-high-blood-pressure/how-potassium-can-help-control-high-blood-pressure",
        "content": (
            "Potassium is one of the most important nutrients for managing high blood pressure. According to "
            "the American Heart Association, potassium-rich foods help reduce the effects of sodium. The more "
            "potassium you eat, the more sodium your body removes through urine. Potassium also helps ease "
            "tension in the walls of blood vessels, which directly helps lower blood pressure.\n\n"
            "The American Heart Association recommends 3,500 to 5,000 milligrams of potassium per day for "
            "adults with elevated or high blood pressure, ideally from food sources rather than supplements. "
            "This is best achieved by following the DASH eating plan, which is specifically designed to be "
            "rich in potassium, magnesium, and calcium — all three nutrients that support healthy blood "
            "pressure.\n\n"
            "Fruits high in potassium include bananas, oranges, orange juice, cantaloupe, apricots, kiwifruit, "
            "and pomegranate juice. A medium banana contains about 451 milligrams of potassium. "
            "Vegetables high in potassium include sweet potatoes, potatoes, spinach, Swiss chard, beet greens, "
            "lima beans, acorn squash, and plantains. Half a cup of plain cooked sweet potato has about 286 "
            "milligrams of potassium. Other good sources include Greek yogurt, low-fat milk, kefir, canned "
            "white beans, lentils, salmon, and tuna.\n\n"
            "Potassium-based salt substitutes are another option for reducing sodium intake and helping "
            "lower blood pressure, particularly for people who cook at home. However, potassium supplements "
            "and salt substitutes should only be used after checking with a healthcare professional, especially "
            "for people with kidney disease or those taking medications that affect potassium levels.\n\n"
            "Eating too much potassium can be harmful for people with kidney problems, since the kidneys "
            "may not be able to remove excess potassium from the blood. Anyone with kidney disease should "
            "consult their doctor before significantly increasing potassium intake.\n\n"
            "To increase potassium naturally through food: add a banana or handful of spinach to breakfast; "
            "swap white rice for a baked sweet potato; include Greek yogurt as a snack; add lentils or white "
            "beans to soups and stews; and choose fresh or frozen vegetables over canned versions, which are "
            "often high in sodium."
        ),
    },
]
