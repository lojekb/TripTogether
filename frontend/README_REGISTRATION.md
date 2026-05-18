Registration UI integration (backend: Django REST)

Required pubspec additions:

- dependencies:
  - provider: ^6.0.5
  - http: ^1.6.0

Commands:

```bash
flutter pub get
flutter test
flutter run -d chrome
```

Notes:
- Set the `baseUrl` passed to `RegistrationPage` (or to `AuthService`) to your backend base URL (e.g. `http://localhost:8000`).
- Ensure CORS is enabled on the backend for web clients.
