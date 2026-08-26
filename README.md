```markdown
# 🐾 Vitail - Dog Wellness App

<div align="center">
  
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Kotlin](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-22d3ee?style=for-the-badge)

</div>

> **"Walk to your next perks."** 
> Vitail is a cross-platform mobile application designed to reward dog owners for keeping their pets healthy and active. Track your daily walks, log your dog's weight, complete weekly quests, and earn points to redeem real-world discounts from local pet-friendly businesses!

---

## ✨ Key Features

- 📍 **Live GPS Walk Tracking:** Accurate, real-time route mapping using Google Maps SDK and the device's Fused Location Provider.
- 🎁 **Rewards & Perks System:** Earn points for every meter walked and redeem them for partner vouchers and premium perks (e.g., free grooming, council fee waivers).
- 📊 **Dynamic Weight Tracker:** Log your dog's weight history with a calendar date-picker and visualize their progress on an interactive line chart (MyFitnessPal style!).
- 🔥 **Gamification & Streaks:** Maintain daily walking streaks and complete weekly quests (e.g., "Walk 1km", "Log Weight") for bonus points.
- 🏞️ **Pet-Friendly Venues:** Explore a curated list of local dog parks, beaches, and cafes with list/map toggle views.
- 🐶 **Rich Pet Profiles:** Set up your dog's profile with breed autocomplete, birthday calculation, sex selection, and upload a profile picture via Supabase Storage.
- 🌗 **Polished UI/UX:** Beautiful, modern interface featuring a dedicated settings hub, light/dark mode toggles, and native splash screens.

---

## 🛠 Tech Stack

**Frontend:**
- **Framework:** Flutter (Dart)
- **State Management:** setState & ValueNotifiers
- **Key Packages:** `google_maps_flutter`, `geolocator`, `supabase_flutter`, `fl_chart`, `image_picker`, `intl`

**Backend (BaaS):**
- **Platform:** Supabase
- **Database:** PostgreSQL (with Row Level Security)
- **Authentication:** Supabase GoTrue (Email/Password)
- **Storage:** Supabase Storage Buckets (Client-side compressed images)

**External APIs:**
- Google Maps SDK for Android/iOS
- Google Play Services Location

---

## 🚀 Getting Started

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0.0+)
2. Install [Android Studio](https://developer.android.com/studio) or VS Code
3. Set up an Android Emulator or physical device
4. Create a free [Supabase](https://supabase.com/) project

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/vitail-app.git
   cd vitail-app
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase Database**
   - Create a new project in Supabase.
   - Go to the SQL Editor and run your database schema scripts (create `profiles`, `dogs`, `walks`, `rewards`, `weight_history`, `daily_tasks` tables with RLS policies).
   - Create a public Storage bucket named `dog_photos` with an INSERT policy for authenticated users.

4. **Configure API Keys**
   - Open `lib/main.dart` and replace the placeholder Supabase URL and Anon Key:
     ```dart
     const String supabaseUrl = 'YOUR_SUPABASE_URL';
     const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     ```
   - Open `android/app/src/main/AndroidManifest.xml` and replace the Google Maps API Key:
     ```xml
     <meta-data android:name="com.google.android.geo.API_KEY"
                android:value="YOUR_GOOGLE_MAPS_API_KEY" />
     ```

5. **Run the App! 🎉**
   ```bash
   flutter run
   ```

---

## 🏗 Architecture

The app follows a **Client-Server Architecture** utilizing a **Backend-as-a-Service (BaaS)** model. 

- The **Flutter client** acts as a thick client, communicating directly with Supabase's auto-generated REST APIs (PostgREST).
- **Security** is enforced at the database level using PostgreSQL Row Level Security (RLS), ensuring users can only access and modify their own dog's data, walks, and photos.
- **Image Optimization** is handled client-side before upload, downscaling and compressing images to optimize network performance and storage costs.

---

<div align="center">
  
*Built with ❤️ for COMP30022 IT Project - The University of Melbourne*

</div>
```