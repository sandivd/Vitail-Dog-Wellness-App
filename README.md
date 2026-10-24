# 🐾 Vitail – Dog Wellness App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Android](https://img.shields.io/badge/Platform-Android-22d3ee?style=for-the-badge)

Vitail is an Android app built with Flutter to help dog owners manage their dog’s daily activity and care. Owners can track walks, monitor progress towards daily goals, earn rewards, discover nearby venues and share care responsibilities with approved carers.

---

## Key Features

- **Daily Goals & Progress:** Personalised walking goals, time and distance progress rings, points balance and daily walking streaks.
- **Live GPS Walk Tracking:** Track routes, time and distance, pause and resume walks, and view live progress from Home.
- **Walk Records & Activity History:** Browse previous walks by date and view saved routes, duration, distance, points, mood, toilet activity, notes and photos.
- **Rewards & Coupons:** Earn walking points, redeem partner offers, manage saved coupons and collect rewards through the check-in flow.
- **Nearby Venues:** Discover parks, vets and cafés, view venue details and start walks towards a selected destination.
- **Dog Profiles & Care Score:** Edit dog details, photos, weight and goals, and view a care-score breakdown covering activity, vaccinations, microchip information, insurance and vet check-ups.
- **Shared Dog Care:** Invite carers using a sharing code, approve or decline join requests and access the shared dog’s activity.
- **Reminders & Settings:** Set daily walking reminders, switch between light and dark modes, export personal data and manage account settings.

---

## Tech Stack

### Frontend

- **Framework:** Flutter (Dart)
- **State Management:** `setState` and `ValueNotifier`
- **Maps & Location:** `google_maps_flutter` and `geolocator`
- **Images:** `image_picker` and `cached_network_image`
- **Notifications:** `flutter_local_notifications`
- **Local Preferences:** `shared_preferences`
- **Other Key Packages:** `supabase_flutter`, `google_sign_in`, `flutter_svg` and `intl`

### Backend

- **Platform:** Supabase
- **Database:** PostgreSQL with Row Level Security (RLS)
- **Authentication:** Supabase Auth with email/password and Google sign-in
- **Storage:** Supabase Storage for dog photos, walk photos and uploaded documents
- **Database Functions:** Supabase RPC calls for operations such as saving walks, calculating activity totals, managing sharing requests and redeeming rewards

### External Services

- Google Maps SDK for map display
- Device location services through `geolocator`
- Google sign-in integrated with Supabase Auth

---

## Architecture

Vitail follows a client–server architecture using Supabase as a Backend-as-a-Service (BaaS).

- **Flutter Client:** Handles the interface, GPS tracking, live walking progress, goal recommendations and care-score presentation.
- **Data Access:** The client communicates with Supabase through its generated REST APIs and database RPC functions.
- **Authentication & Access Control:** Supabase Auth identifies users, while RLS policies control database access according to ownership and approved sharing permissions.
- **Shared Care:** Sharing codes and join requests connect approved carers to a dog’s profile and activity.
- **Photo Storage:** Profile and walk photos use client-side resizing and compression before upload to Supabase Storage.
- **Local Settings & Reminders:** Preferences are stored on the device, and walking reminders are scheduled using local notifications.
