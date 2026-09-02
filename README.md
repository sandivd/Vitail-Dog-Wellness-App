
# 🐾 Vitail - Dog Wellness App

<div align="center">
  
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Android](https://img.shields.io/badge/Platform-Android-22d3ee?style=for-the-badge)

</div>


> Vitail is a cross-platform mobile application designed to reward dog owners for keeping their pets healthy and active. Track your daily walks, log your dog's weight, complete weekly quests, and earn points to redeem real-world discounts from local pet-friendly businesses!

---

## Key Features

- **Live GPS Walk Tracking:** Accurate, real-time route mapping using Google Maps SDK and the device's Fused Location Provider.
- **Rewards & Perks System:** Earn points for every meter walked and redeem them for partner vouchers and premium perks (e.g., free grooming, council fee waivers).
- **Dynamic Weight Tracker:** Log your dog's weight history with a calendar date-picker and visualize their progress on an interactive line chart (MyFitnessPal style!).
- **Gamification & Streaks:** Maintain daily walking streaks and complete weekly quests (e.g., "Walk 1km", "Log Weight") for bonus points.
- **Pet-Friendly Venues:** Explore a curated list of local dog parks, beaches, and cafes with list/map toggle views.
- **Rich Pet Profiles:** Set up your dog's profile with breed autocomplete, birthday calculation, sex selection, and upload a profile picture via Supabase Storage.
- **Polished UI/UX:** Beautiful, modern interface featuring a dedicated settings hub, light/dark mode toggles, and native splash screens.

---

## Tech Stack

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

## Architecture

The app follows a **Client-Server Architecture** utilizing a **Backend-as-a-Service (BaaS)** model. 

- The **Flutter client** acts as a thick client, communicating directly with Supabase's auto-generated REST APIs (PostgREST).
- **Security** is enforced at the database level using PostgreSQL Row Level Security (RLS), ensuring users can only access and modify their own dog's data, walks, and photos.
- **Image Optimization** is handled client-side before upload, downscaling and compressing images to optimize network performance and storage costs.


