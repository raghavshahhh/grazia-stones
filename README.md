# Grazia Stones — AI Smart Estimator

Flutter app (iOS + Android + Web) with real AR wall visualization, AI room photo mode,
wall measurement, and commerce — built for Grazia Stones by [RAGSPRO](https://ragspro.com).

## Documentation

- **[Grazia_Stones_App_Documentation.pdf](docs/Grazia_Stones_App_Documentation.pdf)** — complete app flow, feature status, tech stack
- **[Grazia_Stones_Service_Agreement_Final.pdf](docs/Grazia_Stones_Service_Agreement_Final.pdf)** — commercial terms, scope, payment schedule
- `docs/archive/status-reports/` — historical build session notes (superseded by the App Documentation above)

## Running Locally

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## Project Structure

- `lib/features/` — one folder per screen/feature
- `lib/core/services/ar_native_channel.dart` — Flutter ↔ native AR bridge
- `ios/Runner/AR/` — native ARKit implementation (Swift)
- `android/app/src/main/kotlin/.../ar/` — native ARCore implementation (Kotlin)
- `supabase/` — database schema
