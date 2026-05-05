# KaQuiz — Friend Location Sharing App

A real-time friend location sharing app with user authentication and profile management.

- **Backend:** Go (Gin) + SQLite
- **Frontend:** Flutter (Dart)
- **Auth:** Google Sign-In + JWT tokens
- **Tunneling:** CloudFlare Tunnel (for remote access)

---

## Quick Start

### Prerequisites

- Go 1.20+
- Flutter 3.13+
- CloudFlare (free account for tunneling)
- Google OAuth credentials (client IDs)

### Backend Setup

1. **Navigate to backend:**

   ```bash
   cd backend
   ```

2. **Ensure Go dependencies are installed:**

   ```bash
   go mod tidy
   ```

3. **Run the server (localhost:8080):**
   ```bash
   go run main.go
   ```

### CloudFlare Tunnel Setup

The backend runs on `localhost:8080`. To expose it to the Flutter app (emulator/device), use CloudFlare Tunnel:

1. **Install CloudFlare CLI:**

   ```bash
   brew install cloudflare/cloudflare/cloudflared
   ```

2. **Start the tunnel (in a separate terminal):**

   ```bash
   cloudflared tunnel --url http://127.0.0.1:8080
   ```

   You'll get a URL like: `https://announcement-triumph-lamb-housing.trycloudflare.com`

3. **Note the tunnel URL** — it changes each session.

### Frontend Setup

1. **Navigate to frontend:**

   ```bash
   cd frontend
   ```

2. **Update `.env` file with the tunnel URL:**

   ```env
   BASE_URL=https://announcement-triumph-lamb-housing.trycloudflare.com
   GOOGLE_WEB_CLIENT_ID=<your-google-client-id>
   IOS_CLIENT_ID=<your-ios-client-id>
   ANDROID_CLIENT_ID=<your-android-client-id>
   ```

3. **Install Flutter dependencies:**

   ```bash
   flutter pub get
   ```

4. **Run on emulator or device:**
   ```bash
   flutter run
   ```

---

## Workflow

### When Tunnel URL Changes

The tunnel URL changes each time you restart `cloudflared`. Follow these steps:

1. **Start the tunnel:**

   ```bash
   cloudflared tunnel --url http://127.0.0.1:8080
   ```

2. **Copy the new tunnel URL** from the output.

3. **Update `frontend/.env`:**

   ```
   BASE_URL=<new-tunnel-url>
   ```

4. **Restart Flutter:**
   ```bash
   flutter run
   ```

### Authentication Flow

1. User launches app → **SplashScreen** validates stored JWT token
2. If no token or validation fails → **LoginScreen**
3. User signs in with Google → Backend issues JWT
4. Token stored in secure storage → **MapScreen** opens
5. Sign out clears token and revokes it on server

---

## Project Structure

```
kaquiz/
├── backend/
│   ├── controllers/      # Route handlers (auth, friends, locations, etc.)
│   ├── database/         # GORM setup, migrations
│   ├── middleware/       # JWT validation, auth checks
│   ├── models/           # User, Friendship, Location, RevokedToken
│   ├── routes/           # Gin route definitions
│   ├── main.go           # Entry point
│   ├── go.mod & go.sum   # Dependencies
│   └── swagger.yml       # API documentation
│
└── frontend/
    ├── lib/
    │   ├── screens/      # LoginScreen, MapScreen, SplashScreen
    │   ├── services/     # ApiService, MapTrackingService
    │   ├── widgets/      # Reusable UI components and dialogs
    │   └── main.dart     # App entry point
    ├── pubspec.yaml      # Flutter dependencies
    ├── .env              # Configuration (API base URL, Google client IDs)
    └── ios, android, web, linux, macos, windows/  # Platform-specific configs
```

---

## API Endpoints

| Method | Endpoint                   | Purpose                            |
| ------ | -------------------------- | ---------------------------------- |
| POST   | `/auth`                    | Google login, returns JWT          |
| POST   | `/api/auth/signout`        | Revokes JWT token                  |
| GET    | `/api/users/me`            | Get current user profile           |
| PUT    | `/api/users`               | Update user profile (name, avatar) |
| GET    | `/api/friends`             | List all friends                   |
| POST   | `/api/friends/request`     | Send friend request                |
| POST   | `/api/friends/{id}/accept` | Accept friend request              |
| DELETE | `/api/friends/{id}`        | Remove friend                      |
| POST   | `/api/locations`           | Update own location                |
| GET    | `/api/locations/friends`   | Get friends' current locations     |
| GET    | `/api/invites/pending`     | Get pending friend requests        |

---

## Development Notes

### Avatar Handling

- Avatars are stored as either:
  - **Data URLs** (base64-encoded images): `data:image/jpeg;base64,...`
  - **Remote URLs** (served from backend or CDN)
- Frontend handles both transparently via `ImageProvider` logic
- To upgrade: serve static files from backend (`/static/uploads/`) and store file URLs in DB

### Token Management

- Tokens include a `jti` (JWT ID) claim for revocation tracking
- Revoked tokens are stored in `RevokedToken` model
- Middleware checks revocation status on every protected request
- Tokens expire after a configurable duration (default: 24h)

### Location Updates

- Frontend polls `/api/locations/friends` every 5 seconds
- Friend markers update in real-time on the map
- Your own location is posted every 5 seconds via `POST /api/locations`

---

## Troubleshooting

### "Token validation failed" or "403 Bandwidth limit"

- **Cause:** ngrok or tunnel quota exceeded
- **Solution:** Use CloudFlare Tunnel (free) instead of ngrok

### "Cannot connect to backend" on emulator

- Android emulator cannot reach `localhost:8080` directly
- **Solution:** Use `cloudflared tunnel` and update `BASE_URL` in `.env`

### "Flutter: Login failed" after long disconnection

- **Cause:** Stored token expired or was revoked
- **Solution:** SplashScreen validates token; if invalid, returns to LoginScreen

### "Profile dialog doesn't show avatar"

- **Cause:** Avatar URL may not be loaded yet
- **Solution:** Wait for profile to load or refresh by pulling down in friends list

---

## Future Enhancements

- [ ] File upload endpoint for avatars (avoid base64 in DB)
- [ ] Push notifications for friend requests
- [ ] Real-time updates via WebSocket instead of polling
- [ ] User presence status (online/offline)
- [ ] Location history and trails
- [ ] Dark mode support

---

## Contributing

1. Create feature branches from `main`
2. Test locally before pushing
3. Update `.env` with valid tunnel URL before running
4. Ensure `flutter analyze` and `go vet` pass

---

## License

[Add license here if needed]
