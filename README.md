# 🍳 Bachelor's Kitchen

A simple Flutter recipe app designed for **university students and bachelors living alone in Bangladesh**.

## ✨ Features
- 15+ realistic, low-budget Bangladeshi recipes
- Ingredient list with **quantity**, step-by-step instructions
- **Cost in ৳ (Taka)**, cooking time, difficulty (easy/medium/hard)
- **Category filter**: Breakfast, Lunch, Dinner, Snacks
- **Search** by ingredient name (Bangla or English)
- **AI Chef (offline)** — type the ingredients you have at home, get matching recipes
- **AI Chef (Gemini)** — describe any dish in free text and Gemini generates a full recipe (title, prep time, ingredients, steps)
- **Bangla + English** full bilingual support
- **Favorites** with persistent storage

## 🔑 Optional: Enable Gemini recipe generation

The Gemini feature is opt-in. By default the app builds and runs fine without a key.

1. Get a free API key at <https://aistudio.google.com/apikey>
2. Open `.env` in the project root and replace the placeholder:
   ```env
   GEMINI_API_KEY=your_real_key_here
   ```
3. Hot-restart the app. The AI Chef tab will show a new "Generate with Gemini" card.

The `.env` file is gitignored — your key stays on your machine only.
You can also pass the key at build time:
```bash
flutter run --dart-define=GEMINI_API_KEY=your_real_key_here
```

## 🚀 Run
```bash
flutter pub get
flutter run
```

Built with Flutter, Provider, and SharedPreferences. No backend required.