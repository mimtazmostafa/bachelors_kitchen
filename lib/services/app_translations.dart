import 'package:flutter/material.dart';

import '../models/recipe.dart' show MealCategory, Difficulty;
class AppTranslations {
  final String langCode; // 'en' or 'bn'

  const AppTranslations(this.langCode);

  bool get isBn => langCode == 'bn';

  String t(String en, String bn) => isBn ? bn : en;

  // Static labels (mapped from the active language)
  String get appName => t("Bachelor's Kitchen", 'ব্যাচেলরস কিচেন');
  String get tagline => t(
        'Easy, low-budget recipes for students',
        'ছাত্রদের জন্য সহজ ও সাশ্রয়ী রেসিপি',
      );

  String get home => t('Home', 'হোম');
  String get search => t('Search', 'অনুসন্ধান');
  String get aiChef => t('AI Chef', 'AI শেফ');
  String get favorites => t('Favorites', 'প্রিয়');
  String get ingredients => t('Ingredients', 'উপকরণ');
  String get steps => t('Steps', 'পদ্ধতি');
  String get cookingTime => t('Cooking time', 'রান্নার সময়');
  String get cost => t('Cost', 'খরচ');
  String get difficulty => t('Difficulty', 'কঠিনতা');
  String get servings => t('Servings', 'জন');
  String get minutes => t('min', 'মিনিট');
  String get taka => t('৳', '৳');
  String get perServing => t('per serving', 'প্রতি পরিবেশন');
  String get match => t('Match', 'মিল');
  String get save => t('Save', 'সংরক্ষণ');
  String get saved => t('Saved', 'সংরক্ষিত');
  String get noFavorites => t(
        'No favorites yet — tap the heart icon on any recipe to save it.',
        'এখনো কোনো প্রিয় রেসিপি নেই — হার্ট আইকনে চাপ দিন।',
      );
  String get searchHint => t(
        'Search by ingredient (rice, egg, onion…)',
        'উপকরণ দিয়ে খুঁজুন (ভাত, ডিম, পেঁয়াজ…)',
      );
  String get aiHint => t(
        'Type the ingredients you have at home\n(e.g. rice, egg, onion, chili)',
        'ঘরে যে উপকরণ আছে লিখুন\n(যেমন: ভাত, ডিম, পেঁয়াজ, মরিচ)',
      );  String get aiEmpty => t(
        'Type a few ingredients to see what you can cook.',
        'কিছু উপকরণ লিখে দেখুন কী রান্না করা যায়।',
      );
  String get findRecipes => t('Find Recipes', 'রেসিপি খুঁজুন');
  String get matchScore => t('Match', 'মিল');
  String get matchPerfect => t(
        'Perfect match!',
        'সম্পূর্ণ মিল!',
      );
  String get matchGood => t('Good match', 'ভালো মিল');
  String get matchPartial => t('Partial match', 'আংশিক মিল');
  String get missing => t('You still need', 'আপনার আরও দরকার');
  String get have => t('You have', 'আপনার আছে');
  String get categoryAll => t('All', 'সব');
  String get breakfast => t('Breakfast', 'সকালের নাস্তা');
  String get lunch => t('Lunch', 'দুপুরের খাবার');
  String get dinner => t('Dinner', 'রাতের খাবার');
  String get snack => t('Snacks', 'নাস্তা');
  String get easy => t('Easy', 'সহজ');
  String get medium => t('Medium', 'মাঝারি');
  String get hard => t('Hard', 'কঠিন');
  String get recipes => t('Recipes', 'রেসিপি');
  String get estimated => t('Estimated', 'আনুমানিক');
  String get cookNow => t("Let's Cook", 'রান্না শুরু');
  String get seeFullRecipe => t('See full recipe', 'সম্পূর্ণ রেসিপি দেখুন');
  String get tipTitle => t('Bachelor Tip', 'ব্যাচেলর টিপস');

  /// Returns the tip for today from a rotating list.
  /// Pass [seed] to override the day-based selection (e.g. when the
  /// user taps the "new tip" button).
  String tipBodyForToday({int seed = 0}) {
    const tipsEn = <String>[
      'Keep onions, garlic, ginger and green chili at home — they make 80% of Bangladeshi dishes come alive!',
      'A squeeze of lemon brightens any dal or fried rice — always keep lemons on hand.',
      'Buy rice, lentils and eggs in bulk from the wholesale market — cheaper per kilo.',
      'Don\'t skip the mustard oil "tadka" — it\'s the soul of Bangladeshi cooking.',
      'A frozen bag of mixed vegetables saves you on lazy days and costs less than takeout.',
      'Toast your spices (cumin, coriander) before grinding — unlocks 2x the flavor.',
      'Cook once, eat twice: a pot of dal or chicken curry tastes even better the next day.',
      'Save your pasta water — a splash of salty starchy water fixes bland everything.',
      'Curd (doi) is a bachelor\'s secret sauce: marinade, tenderize, thicken — all in one.',
      'A pinch of sugar balances spicy curries. Don\'t fear the sweet.',
    ];
    const tipsBn = <String>[
      'বাসায় পেঁয়াজ, রসুন, আদা ও কাঁচামরিচ রাখুন — এগুলো ছাড়া ৮০% বাংলা রান্না অসম্পূর্ণ!',
      'ডাল বা ভাজি ভাতে একটু লেবুর রস চিপে দিলে স্বাদ বদলে যায় — সবসময় লেবু রাখুন।',
      'পাইকারি বাজার থেকে চাল, ডাল ও ডিম কিনলে কেজিপ্রতি দাম অনেক কম পড়ে।',
      'সরিষার তেলে তড়কা দেওয়া বাদ দেবেন না — এটাই বাংলা রান্নার আত্মা।',
      'ফ্রিজে এক ব্যাগ মিক্স ভেজিটেবিজ রাখুন — অলস দিনে বাঁচায়, বাইরের খাবারের চেয়ে সস্তা।',
      'মশলা (জিরা, ধনে) শুকনো ভেজে নিন — স্বাদ দ্বিগুণ হয়।',
      'একবার রান্না করে দু\'দিন খান — ডাল বা মুরগির ঝোল পরের দিন আরও ভালো লাগে।',
      'পাস্তার রান্নার পানি ফেলে দেবেন না — এক চিমটি লবণাক্ত পানি ব্যতিক্রমহীন স্বাদ বাড়ায়।',
      'দই ব্যাচেলরের গোপন অস্ত্র: মেরিনেড, নরম করা, ঘন করা — সব একসাথে।',
      'এক চিমটি চিনি ঝাল ঝোলের ভারসাম্য আনে। মিষ্টি ভয় পাবেন না।',
    ];
    final tips = isBn ? tipsBn : tipsEn;
    final int base;
    if (seed == 0) {
      base = DateTime.now()
          .difference(DateTime(DateTime.now().year, 1, 1))
          .inDays;
    } else {
      base = seed;
    }
    return tips[base % tips.length];
  }

  String tipBodyForSeed(int seed) => tipBodyForToday(seed: seed);
  String get tipBody => tipBodyForToday();

  String get refresh => t('New tip', 'নতুন টিপস');
  String get languageToggle => t('EN / বাং', 'EN / বাং');
  String get languageBn => t('বাংলা', 'বাংলা');
  String get languageEn => t('English', 'English');

  String get budget => t('Budget', 'বাজেট');
  String get budgetAll => t('All', 'সব');
  String get underFifty => t('Under ৳50', '৫০ টাকার নিচে');
  String get underHundred => t('Under ৳100', '১০০ টাকার নিচে');
  String get underHundredFifty => t('Under ৳150', '১৫০ টাকার নিচে');
  String get underTwoHundred => t('Under ৳200', '২০০ টাকার নিচে');

  String get planner => t('Meal Planner', 'সাপ্তাহিক মেনু');
  String get weeklyPlan => t('Weekly Meal Planner', 'সাপ্তাহিক মেনু প্ল্যানার');
  String get shoppingList => t('Shopping List', 'কেনাকাটার তালিকা');
  String get totalCost => t('Total cost', 'মোট খরচ');
  String get pickADish => t('Pick a dish for this day', 'এই দিনের জন্য একটি রান্না বেছে নিন');
  String get clearWeek => t('Clear week', 'সপ্তাহ মুছুন');
  String get dayMonday => t('Mon', 'সোম');
  String get dayTuesday => t('Tue', 'মঙ্গল');
  String get dayWednesday => t('Wed', 'বুধ');
  String get dayThursday => t('Thu', 'বৃহঃ');
  String get dayFriday => t('Fri', 'শুক্র');
  String get daySaturday => t('Sat', 'শনি');
  String get daySunday => t('Sun', 'রবি');

  String get startCooking => t('Start Cooking', 'রান্না শুরু');
  String get stepTimer => t('Step timer', 'ধাপের টাইমার');
  String get pause => t('Pause', 'বিরতি');
  String get resume => t('Resume', 'চালিয়ে যান');
  String get reset => t('Reset', 'রিসেট');
  String get setTime => t('Set time (min)', 'সময় দিন (মিনিট)');

  // Gemini AI recipe generator
  String get generateWithGemini =>
      t('Generate with Gemini AI', 'Gemini AI দিয়ে তৈরি করুন');
  String get aiPromptHint => t(
        'e.g. cheap chicken dinner with rice for one person',
        'যেমন: একজনের জন্য ভাতসহ সস্তা মুরগির রাতের খাবার',
      );
  String get aiPromptLabel => t(
        'Describe what you want to cook',
        'আপনি কী রান্না করতে চান তা লিখুন',
      );
  String get aiGenerating => t('Generating recipe…', 'রেসিপি তৈরি হচ্ছে…');
  String get aiRecipeTitle => t('AI recipe', 'AI রেসিপি');
  String get aiPrepTime => t('Prep time', 'প্রস্তুতির সময়');
  String get aiIngredients => t('Ingredients', 'উপকরণ');
  String get aiSteps => t('Steps', 'ধাপসমূহ');
  String get aiNoKey => t(
        'Add a Gemini API key to .env to enable AI recipes.',
        'AI রেসিপি চালু করতে .env ফাইলে Gemini API key যোগ করুন।',
      );
  String get aiPowered => t('Powered by Gemini', 'Gemini দ্বারা চালিত');

  // Subscription / paywall
  String get subscribeTitle => t(
        'Welcome to the kitchen world',
        'রান্নার দুনিয়ায় স্বাগতম',
      );
  String get subscribeSubtitle => t(
        'Just ৳2.78/day — unlock every recipe and AI Chef',
        'শুধু ৳২.৭৮/দিন — প্রতিটি রেসিপি এবং AI Chef আনলক করুন',
      );
  String get subscribeTagline => t(
        'Easy cooking, low cost',
        'সহজ রান্না, কম খরচ',
      );
  String get featureRecipes => t(
        '15+ বাংলাদেশি রেসিপি',
        '১৫+ বাংলাদেশি রেসিপি',
      );
  String get featureAiChef => t(
        'AI Chef assistance',
        'AI শেফ সহায়তা',
      );
  String get featurePlanner => t(
        'Weekly meal planner',
        'সাপ্তাহিক মেনু পরিকল্পক',
      );
  String get featureOffline => t(
        'Offline access',
        'অফলাইন অ্যাক্সেস',
      );
  String get phoneLabel => t(
        'Robi / Airtel',
        'রবি / এয়ারটেল',
      );
  String get phoneHint => t(
        '1XXXXXXXXX',
        '1XXXXXXXXX',
      );
  String get sendOtp => t('Send OTP', 'OTP পাঠান');
  String get otpSent => t(
        'OTP sent! Check your SMS.',
        'OTP পাঠানো হয়েছে! আপনার SMS চেক করুন।',
      );
  String get otpLabel => t('Enter the 6-digit code', '৬-সংখ্যার কোড দিন');
  String get verifyOtp => t('Verify & Subscribe', 'OTP যাচাই করুন এবং সাবস্ক্রাইব করুন');
  String get resendOtp => t('Resend OTP', 'OTP আবার পাঠান');
  String get changeNumber => t('Change number', 'নম্বর পরিবর্তন করুন');
  String get subscriptionSuccess => t(
        'Welcome aboard! Loading kitchen…',
        'স্বাগতম! রান্নাঘর লোড হচ্ছে…',
      );
  String get enterValidPhone => t(
        'Robi or Airtel number only',
        'শুধুমাত্র রবি এবং এয়ারটেল নাম্বার প্রযোজ্য',
      );
  String get enterValidOtp => t(
        'Enter the 6-digit OTP',
        'সঠিক ৬ সংখ্যার OTP দিন',
      );

  // Login / re-verify
  String get loginTitle => t(
        'Welcome back',
        'আবারও স্বাগতম',
      );
  String get loginSubtitle => t(
        'Verify your number to continue cooking',
        'রান্না চালিয়ে যেতে আপনার নম্বর যাচাই করুন',
      );
  String get loginButton => t(
        'Verify & Continue',
        'যাচাই করুন ও চালিয়ে যান',
      );
  String get noSubscription => t(
        'No active subscription on this number.',
        'এই নম্বরে কোনো সক্রিয় সাবস্ক্রিপশন নেই।',
      );
  String get subscribeButton => t(
        'Subscribe now',
        'এখনই সাবস্ক্রাইব করুন',
      );
  String get networkError => t(
        'Network or server problem. Please try again.',
        'ইন্টারনেট সংযোগ বা সার্ভার সমস্যা। কিছুক্ষণ পর আবার চেষ্টা করুন।',
      );
  String get tooManyAttempts => t(
        'Too many attempts. Please try again later.',
        'অনেকবার চেষ্টা করা হয়েছে। কিছুক্ষণ অপেক্ষা করে আবার চেষ্টা করুন।',
      );
  String get operatorNotAllowed => t(
        'This number is not allowed for the subscribed operator. Please use a Robi (018) or Airtel (016) number.',
        'এই নম্বরটি এই অপারেটরের জন্য অনুমোদিত নয়। Robi (018) বা Airtel (016) নম্বর ব্যবহার করুন।',
      );

  // Settings / account
  String get settings => t('Settings', 'সেটিংস');
  String get account => t('Account', 'অ্যাকাউন্ট');
  String get subscribedWith => t(
        'Subscribed with',
        'সাবস্ক্রাইব করা নম্বর',
      );
  String get subscriberId => t('Subscriber ID', 'সাবস্ক্রাইবার আইডি');
  String get notSubscribed => t(
        'Not subscribed',
        'সাবস্ক্রিপশন নেই',
      );
  String get logout => t('Log out', 'লগ আউট');
  String get logoutConfirmTitle => t('Log out?', 'লগ আউট করবেন?');
  String get logoutConfirmBody => t(
        'You will need to verify your number again to access recipes and AI Chef.',
        'রেসিপি ও AI Chef ব্যবহার করতে আবার আপনার নম্বর যাচাই করতে হবে।',
      );
  String get cancel => t('Cancel', 'বাতিল');
  String get confirm => t('Log out', 'লগ আউট');
  String get unsubscribe => t('Unsubscribe', 'সাবস্ক্রিপশন বাতিল করুন');
  String get unsubscribeConfirmTitle => t(
        'Cancel subscription?',
        'সাবস্ক্রিপশন বাতিল করবেন?',
      );
  String get unsubscribeConfirmBody => t(
        'You will lose access to all recipes and AI Chef. This cannot be undone.',
        'সব রেসিপি ও AI Chef-এর অ্যাক্সেস হারাবেন। এটি ফেরানো যাবে না।',
      );
  String get unsubscribeConfirm => t(
        'Yes, cancel',
        'হ্যাঁ, বাতিল করুন',
      );
  String get appVersion => t('App version', 'অ্যাপের সংস্করণ');
  String get poweredByBdapps => t(
        'Powered by bdapps',
        'bdapps দ্বারা পরিচালিত',
      );

  String categoryLabel(MealCategory c) {
    switch (c) {
      case MealCategory.breakfast:
        return breakfast;
      case MealCategory.lunch:
        return lunch;
      case MealCategory.dinner:
        return dinner;
      case MealCategory.snack:
        return snack;
    }
  }

  String difficultyLabel(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return easy;
      case Difficulty.medium:
        return medium;
      case Difficulty.hard:
        return hard;
    }
  }

  Color difficultyColor(Difficulty d) {
    switch (d) {
      case Difficulty.easy:
        return const Color(0xFF2E7D32);
      case Difficulty.medium:
        return const Color(0xFFF9A825);
      case Difficulty.hard:
        return const Color(0xFFC62828);
    }
  }

  String matchLabel(double score) {
    if (score >= 0.99) return matchPerfect;
    if (score >= 0.6) return matchGood;
    return matchPartial;
  }
}