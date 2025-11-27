# Food Rx: Your Personal Nutrition & Recipe Companion

<p align="center">
  <img src="https://placehold.co/600x300/FFF3EB/FF6A00?text=My+Food+Rx" alt="My Food Rx Banner">
</p>

**My Food Rx** is a comprehensive mobile application built with Flutter that provides personalized nutritional guidance to help you take control of your health. It combines smart recipe generation, pantry management, personalized diet plans, and daily health tracking into one seamless experience.

---

## ✨ Features

- **🍎 Personalized Diet Plans**: Get a tailored diet plan (DASH or MyPlate) based on a detailed onboarding process that captures your health goals, medical conditions, and dietary preferences.
- **🧑‍🍳 Smart Recipe Generation**: Discover recipes that you can make right now. The app analyzes your pantry, prioritizes expiring ingredients, and filters recipes based on your specific health needs (e.g., low-sodium, low-sugar).
- **📝 Pantry Management**: Easily track your food inventory. Add items to your virtual pantry, categorize them, and get reminders for expiring goods.
- **🎯 Daily & Weekly Health Tracking**: Stay on top of your goals with a dashboard that tracks your daily intake of water, vegetables, protein, and other essential nutrients.
- **📚 Educational Content**: Browse and bookmark articles on nutrition, healthy eating, and managing health conditions.
- **🤖 AI-Powered Chatbot**: Have a question about a food item or nutrition? Our Dialogflow-powered chatbot is here to help 24/7.
- **🔐 Secure Authentication**: Your data is protected with secure user authentication and password hashing.

---

## 🛠️ Tech Stack & Architecture

Food Rx is built with a modern stack, designed for scalability and a smooth user experience.

- **Frontend**: Flutter
- **State Management**: Provider
- **Database**: MongoDB
- **Food Data & Recipes**: Spoonacular API
- **Chatbot**: Google Cloud Dialogflow
- **Backend Automation**: Google Cloud Functions (for scheduled tasks like resetting trackers)

The project follows a **feature-first architecture**, where code is organized by feature (e.g., `auth`, `recipes`, `pantry`). This makes the codebase modular, easier to navigate, and simpler to maintain.

---

## 🚀 Getting Started

Follow these steps to get the Food Rx project up and running on your local machine.

### 1. Prerequisites

- Flutter SDK (version >=3.35.3 <4.0.0)
- An IDE (like VS Code or Android Studio) with the Flutter plugin.
- Install Ruby using Homebrew:
  - `brew install ruby`
  - `echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc`
  - `echo 'export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"' >> ~/.zshrc`
  - `source ~/.zshrc`  
- Install CocoaPods:
  - `gem install cocoapods`
- Access to:
  - A MongoDB database.
  - A Spoonacular API key.
  - A Google Cloud Platform project with Dialogflow CX enabled.

### 2. Clone the Repository

```bash
git clone [https://github.com/jariwala-jay/food-rx-app.git](https://github.com/jariwala-jay/food-rx-app.git)
cd food-rx-app
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Configure Environment Variables

The application uses a `.env` file to manage sensitive API keys and configuration.

1.  Create a file named `.env` in the root of the project.
2.  Add the following configuration details. You will need to replace the placeholder values with your own keys.

    ```env
    # MongoDB Connection String
    MONGODB_URL="mongodb+srv://<user>:<password>@<cluster-uri>/<database-name>?retryWrites=true&w=majority"

    # Dialogflow Configuration
    DIALOGFLOW_PROJECT_ID="your-gcp-project-id"
    DIALOGFLOW_AGENT_ID="your-dialogflow-agent-id"
    DIALOGFLOW_LOCATION="global"
    DIALOGFLOW_LANGUAGE_CODE="en"

    # API KEYS
    GEMINI_API_KEY="gemini-key"
    RAPID_API_KEY="spoonacular-rapid-api-key"

    # FLAGS
    SHOW_SCALING_CONVERSION=false
    MANDATORY_PLAN_VIDEO=false

    # VIDEO URLs (Required - videos are hosted in cloud storage)
    # Get these URLs from Firebase Storage
    DASH_VIDEO_URL="https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/videos%2Fdash.mp4?alt=media&token=..."
    MYPLATE_VIDEO_URL="https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/videos%2Fmyplate.mp4?alt=media&token=..."
    DIABETES_PLATE_VIDEO_URL="https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/videos%2Fdiabetes_plate.mp4?alt=media&token=..."
    ```

3.  **Dialogflow Service Account**: Place your Google Cloud service account JSON key file in `assets/dialogflow_auth.json`. This is required for the chatbot to authenticate with Google's services.

> **Note**: The `.env` file and `dialogflow_auth.json` are listed in `.gitignore` and should **never** be committed to your repository.

### 5. Run the Application

You can now run the app on a connected device or simulator:

```bash
flutter run
```

---

## 📖 Wiki & Documentation

For a deeper dive into the app's architecture, feature implementation, and backend services, please visit our **[Project Wiki](https://github.com/jariwala-jay/food-rx-app/wiki)**.

---

## 🙌 Contributing

We welcome contributions to Food Rx! If you'd like to contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature-name`).
3.  Make your changes and commit them (`git commit -m 'Add some feature'`).
4.  Push to the branch (`git push origin feature/your-feature-name`).
5.  Open a Pull Request.

Please make sure to write clean code, add comments where necessary, and follow the existing project structure.
