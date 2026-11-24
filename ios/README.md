# Listings for iOS

A native SwiftUI client for the Go listings API in `../backend`. It covers the same
features as the web frontend: browse and search listings, sign in or register,
post, edit and delete listings with photos, save listings, and plan meetups.

Requires **Xcode 16 or later** and runs on **iOS 17+** (Simulator or device).

## Run it

1. Start the backend first (see `../backend/README.md`). The Docker steps there
   start PostgreSQL, run the migrations, and serve the API on `http://localhost:8080`.
   Set `API_BASE_URL=http://localhost:8080` so photo URLs come back absolute.
2. Open `Listings.xcodeproj` in Xcode.
3. Pick an iPhone simulator (for example iPhone 16) and press **Run** (⌘R).

The Simulator shares your Mac's network, so `http://localhost:8080` works as-is.
If the API isn't running, the Explore tab shows sample listings and a
**Retry connection** button, so the app still demos offline.

To run on a physical iPhone, select your Apple ID team under
*Signing & Capabilities*, then in the app's **Account** tab set the server to
your Mac's local network address (for example `http://192.168.1.20:8080`).

## How it maps to the assignment

| Requirement | Where |
| --- | --- |
| Native mobile app with multiple screens ("activities") | `Views/`: Explore, Listing detail, Post/Edit listing, Sign in, Sell, Saved, Meetups, Account |
| Service component | `Services/ListingSyncService.swift` refreshes listings from the API every 30 seconds while the app is active. `Services/MeetupReminderService.swift` schedules local notifications before meetups. |
| Database CRUD (server) | `Networking/APIClient.swift`: create, read, update and delete listings in PostgreSQL through the Go API |
| Database CRUD (on device) | `Models/LocalModels.swift`: SwiftData (SQLite) stores saved listings and meetup plans; create, read, update and delete meetups |
| Runs on an emulator | iOS Simulator |

No third-party packages or templates are used. The app uses only Apple frameworks:
SwiftUI, SwiftData, PhotosUI and UserNotifications.

## Project layout

```
Listings/
  App/          ListingsApp (entry point), AppModel (app state)
  Models/       Listing, User (API models), LocalModels (SwiftData)
  Networking/   APIClient, MultipartForm (photo uploads)
  Services/     ListingSyncService, MeetupReminderService, PhotoProcessor
  Views/        SwiftUI screens and shared components
  Samples/      Offline sample photos (same as the web frontend)
Support/Info.plist   Allows plain HTTP to localhost / local network only
```

The project uses Xcode's folder-synchronized groups, so new `.swift` files added
under `Listings/` are picked up automatically. There's no need to drag them into Xcode.

## Notes

- Photos are converted to JPEG and downscaled to 1600 px before upload, because
  the API accepts only JPEGs of 10 MB or less.
- The API doesn't issue sessions or check listing ownership. Edit and delete buttons
  only appear on your own listings, but that's a UI check only, same as the web app.
- Saved listings and meetup plans stay on the device; the API has no endpoints for them.
