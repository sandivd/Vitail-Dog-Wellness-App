
# 🐾 Vitail - Dog Wellness App

<div align="center">
  
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Android](https://img.shields.io/badge/Platform-Android-22d3ee?style=for-the-badge)

</div>


> Vitail is a cross-platform mobile application designed to reward dog owners for keeping their pets healthy and active. Track your daily walks, log your dog's weight, and earn points to redeem real-world discounts from local pet-friendly businesses!

---

## Key Features

- **Daily Goals & Progress:** Personalised walking goals, time and distance progress rings, points balance and daily streaks.
- **Live GPS Walk Tracking:** Track routes, time and distance, pause and resume walks, and view live progress from Home.
- **Walk Records & Activity History:** Browse previous walks by date and view saved routes, duration, distance, points, mood, toilet activity, notes and photos.
- **Rewards & Coupons:** Earn walking points, redeem partner offers, manage saved coupons and collect rewards through the check-in flow.
- **Nearby Venues:** Discover parks, vets and cafés, view venue details and start walks towards a selected destination.
- **Dog Profiles & Care Score:** Edit dog details, photos, weight and goals, and view a care-score breakdown covering activity and recorded care information.
- **Shared Dog Care:** Invite carers using a sharing code, approve or decline join requests and access the shared dog’s activity.
- **Reminders & Settings:** Set daily walking reminders, switch between light and dark modes, export personal data and manage account settings.

---

## Tech Stack

**Frontend:**
- **Framework:** Flutter (Dart)
- **State Management:** setState & ValueNotifiers
- **Key Packages:** `google_maps_flutter`, `geolocator`, `supabase_flutter`, `fl_chart`, `image_picker`, `intl`

**Backend (BaaS):**
- **Platform:** Supabase
- **Database:** PostgreSQL (with Row Level Security)
- **Authentication:** Supabase Auth (Email/Password) and Google OAuth
- **Storage:** Supabase Storage Buckets (Client-side compressed images)

**External APIs:**
- Google Maps SDK for Android/iOS
- Google Routes API (walking-route estimates; called through a Supabase Edge Function)
- Google Play Services Location

### Walking route estimates

Venue point estimates use Google's walking-route distance instead of straight-line
distance. To configure the server-side route lookup, enable the Google Routes API
and billing in Google Cloud, then set the key as a Supabase secret and deploy the
function from the linked project:

```sh
supabase secrets set GOOGLE_ROUTES_API_KEY=your_key
supabase functions deploy estimate-walking-route
```

Keep this key in Supabase; do not add it to the Flutter app or commit it to the
repository. The venue estimate is based on the suggested pedestrian route and
may differ from the final points because the walked GPS route can change.

---

## Architecture

The app follows a **Client-Server Architecture** utilizing a **Backend-as-a-Service (BaaS)** model. 

- The **Flutter client** acts as a thick client, communicating directly with Supabase's auto-generated REST APIs (PostgREST).
- **Security** is enforced at the database level using PostgreSQL Row Level Security (RLS), ensuring users can only access and modify their own dog's data, walks, and photos.
- **Image Optimization** is handled client-side before upload, downscaling and compressing images to optimize network performance and storage costs.
