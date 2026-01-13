# Anonymous Bamboo Forest (Flutter App)

## Getting Started

1.  Ensure you have Flutter installed.
2.  Run `flutter pub get` to install dependencies.
3.  Ensure the FastAPI backend is running on `http://localhost:8000`.

## Running

-   **Web**: `flutter run -d chrome`
-   **iOS Simulator**: `flutter run -d iphonesimulator`
-   **Android Emulator**: The app tries to connect to `10.0.2.2:8000`. Run `flutter run -d android`.

## Features

-   View anonymous posts with TTL countdown.
-   Create new posts (max 200 chars).
-   Recommend posts to extend their life.
-   Report inappropriate posts.
-   View Rankings (Most Viewed, Most Recommended).
