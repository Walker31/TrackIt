/// When in the day a line fits.
enum NudgeSlot { morning, lunch, afternoon, evening, weekend, any }

/// One daytime nudge: a short title and a line under it.
typedef NudgeLine = ({NudgeSlot slot, String title, String body});

/// The daytime "log your spending" nudges. Short, friendly, never scolding:
/// a gentle tap, not a lecture. Written for TrackIt.
const List<NudgeLine> nudgeLines = [
  // ---- Morning (10 to 12) ----
  (
    slot: NudgeSlot.morning,
    title: 'Morning chai, logged?',
    body: 'Ten seconds now saves guessing tonight.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Fresh day, fresh ledger',
    body: 'Start it right: add your first spend.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Auto fare, metro, coffee?',
    body: 'The commute adds up. Note it down.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Good morning, money manager',
    body: 'Anything spent yet? Tap to add it.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Breakfast counts too',
    body: 'That dosa deserves a line in your wallet.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Quick one before work?',
    body: 'Add this morning\'s spends in a tap.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Your budget woke up too',
    body: 'Give it something to look at.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Small spends, big picture',
    body: 'Log the little ones while you remember.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Paid for parking?',
    body: 'Every ₹20 tells part of the story.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Rise and record',
    body: 'One tap, one expense, done.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Coffee first, tracking second',
    body: 'Now it\'s second. Add it?',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Topped up your metro card?',
    body: 'Pop it in before the day takes over.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Groceries on the way?',
    body: 'Log the bill while the receipt\'s still warm.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Early bird gets the budget',
    body: 'Get today\'s first entry in.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Newspaper, milk, bread?',
    body: 'Daily basics still count. Add them.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Day one of a good habit',
    body: 'Or day forty. Either way, tap to log.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Before the meetings begin',
    body: 'Thirty seconds for your wallet.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'What did the morning cost?',
    body: 'Find out in one tap.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Fuelled up today?',
    body: 'Petrol or coffee, both belong here.',
  ),
  (
    slot: NudgeSlot.morning,
    title: 'Clear head, clear accounts',
    body: 'Note this morning\'s spends now.',
  ),

  // ---- Lunch (12 to 3) ----
  (
    slot: NudgeSlot.lunch,
    title: 'Lunch logged?',
    body: 'Thali, biryani or salad, it all counts.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Food delivery just arrived?',
    body: 'Add it before you dig in.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Split the bill at lunch?',
    body: 'Add it to the event so no one forgets.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Midday money check',
    body: 'How\'s today looking? Tap to add.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Canteen or café?',
    body: 'Wherever you ate, log what you paid.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Hungry for a good budget?',
    body: 'Feed it today\'s lunch.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'That chai break counts',
    body: 'Even ₹15 matters by month end.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Paid by UPI just now?',
    body: 'Copy the SMS and paste it in. Done.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Halfway through the day',
    body: 'Halfway to a full log. Add what\'s new.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Snack attack?',
    body: 'Samosas are tiny. Their total isn\'t.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Lunch with the team?',
    body: 'Log your share in a tap.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Ordered in again?',
    body: 'No judgement. Just log it.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'A quick bite, a quick log',
    body: 'Ten seconds, tops.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Spent on lunch?',
    body: 'Your Food & Dining budget is curious.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Tiffin or takeaway?',
    body: 'Takeaway goes in the app.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Post-lunch slump?',
    body: 'Wake up with a tiny win: log a spend.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Your wallet\'s lunch break',
    body: 'Tell it what happened today.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Paid the chaiwala?',
    body: 'Small change, still change. Add it.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Noon numbers',
    body: 'Catch up on the morning\'s spends now.',
  ),
  (
    slot: NudgeSlot.lunch,
    title: 'Dessert was extra?',
    body: 'So is logging it. Worth it.',
  ),

  // ---- Afternoon (3 to 6) ----
  (
    slot: NudgeSlot.afternoon,
    title: 'Afternoon check-in',
    body: 'Anything bought since lunch?',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Online cart checked out?',
    body: 'Log it now, thank yourself later.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Tea-time tally',
    body: 'Add today\'s spends before the evening rush.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'A bill just got paid?',
    body: 'Electricity, phone, Wi-Fi: log it.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Running an errand?',
    body: 'Note what it cost while you\'re out.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'How\'s the budget holding up?',
    body: 'One tap to keep it honest.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Recharge done?',
    body: 'Mobile and DTH count too.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Cab home booked?',
    body: 'Add the fare when you get in.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Quick pause?',
    body: 'Use it to log the day so far.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Bought something nice?',
    body: 'Enjoy it. Then add it.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Gym fee or protein shake?',
    body: 'Health & Fitness spends go here.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'The 4 PM money moment',
    body: 'Small habit, big clarity. Tap to log.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Did you pay anyone today?',
    body: 'Friends, shops, sites: add them in.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Receipt in your pocket?',
    body: 'Turn it into a two-second entry.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Paid back a friend?',
    body: 'Settle it in TrackIt too.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Groceries for tonight?',
    body: 'Log the bill on the way home.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'An afternoon well spent?',
    body: 'Let\'s see exactly how well.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Still remember what you spent?',
    body: 'Now\'s the best time to add it.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Your future self says hi',
    body: 'They\'d love an up-to-date log.',
  ),
  (
    slot: NudgeSlot.afternoon,
    title: 'Quick wallet catch-up',
    body: 'Add anything new since morning.',
  ),

  // ---- Early evening (6 to 8) ----
  (
    slot: NudgeSlot.evening,
    title: 'Heading home?',
    body: 'Log today\'s spends before you switch off.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Dinner plans?',
    body: 'Note the order when it lands.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Wrapping up the day',
    body: 'Close the loop: add today\'s spends.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Evening snack run?',
    body: 'Pani puri counts. Add it.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Shopping bags in hand?',
    body: 'Log them before the receipts vanish.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Movie tickets booked?',
    body: 'Entertainment wants its entry.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Sunset, then spend-set',
    body: 'Record the day\'s money in a tap.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Out with friends?',
    body: 'Add a shared expense and split it later.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'The day is almost done',
    body: 'Your log can be too. Tap to finish it.',
  ),
  (
    slot: NudgeSlot.evening,
    title: 'Fuel stop on the way back?',
    body: 'Transport spends go here.',
  ),

  // ---- Weekends ----
  (
    slot: NudgeSlot.weekend,
    title: 'Weekend mode on',
    body: 'Brunch, movies, shopping? Log as you go.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Saturday spree?',
    body: 'Have fun. TrackIt will remember.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Lazy Sunday, light logging',
    body: 'Just one tap for today\'s spends.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Weekend getaway?',
    body: 'Add it to a trip and see what it cost.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Brunch o\'clock',
    body: 'Log it between bites.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Mall day?',
    body: 'Every bag tells a story. Add them.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Weekend market haul?',
    body: 'Veggies, fruit, flowers: all welcome.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Family outing?',
    body: 'Split it in an event, or log it here.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Sunday reset',
    body: 'Catch up on the week\'s missed spends.',
  ),
  (
    slot: NudgeSlot.weekend,
    title: 'Game night snacks?',
    body: 'Log them before they disappear.',
  ),

  // ---- Any time ----
  (
    slot: NudgeSlot.any,
    title: 'Spent something?',
    body: 'Tap to add it in seconds.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'A tiny habit, a clear month',
    body: 'Log today\'s spends now.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Your wallet has news',
    body: 'Tell TrackIt what you spent.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Money in, money out',
    body: 'Keep both honest with a quick log.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Where did the ₹500 go?',
    body: 'Never wonder again. Log it now.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Budget whisperer, reporting in',
    body: 'Got a spend for me?',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Future you is watching',
    body: 'Kindly. Add today\'s spends.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'One tap closer to your goal',
    body: 'Logged spends make savings real.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Paid via UPI?',
    body: 'Paste the SMS and we\'ll fill it in.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Small spends sneak up',
    body: 'Catch them before month end does.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Keep the streak alive',
    body: 'Log one spend today.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Rupee by rupee',
    body: 'That\'s how budgets are won. Add one.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Remember that purchase?',
    body: 'You will if you log it now.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Money diary time',
    body: 'Dear diary, today I spent…',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Track it, don\'t stress it',
    body: 'Quick add is one tap away.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Spent cash today?',
    body: 'Cash leaves no SMS. Add it by hand.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Your savings goal says hi',
    body: 'Logging helps it grow. Tap to add.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Numbers love company',
    body: 'Give today\'s spends a home.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Two seconds, promise',
    body: 'Amount, category, done.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Know where it goes',
    body: 'Then decide where it should go.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Swiped your card?',
    body: 'Log it before the bill reminds you.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'A clear head starts here',
    body: 'Note today\'s spends in a tap.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Little leaks sink big ships',
    body: 'Spot them: log every spend.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'You vs. month end',
    body: 'Logging is your secret weapon.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Bought a gift?',
    body: 'Generous you deserves a tidy log.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Tip, fee, or charge?',
    body: 'The sneaky ones count too.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Spent, then forgot?',
    body: 'Not on our watch. Tap to add.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Mind the money',
    body: 'A quick log keeps it in sight.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Your budget misses you',
    body: 'Drop in with today\'s spends.',
  ),
  (
    slot: NudgeSlot.any,
    title: 'Clarity costs ₹0',
    body: 'Logging is free. Spending isn\'t.',
  ),
];
