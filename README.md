# Listings

A face-to-face buy, sell and trade marketplace for college students, launching first at Towson University.
COSC 412-101, Fall 2026, Assignment 4: Application Design Prototype.

**Repository:** https://github.com/ussg43/listings (public, so no account or invite is needed to view or clone it)

## What's in this repository

| Folder | What it is |
| --- | --- |
| `backend/` | Go REST API with a PostgreSQL database (create, read, update and delete for users and listings) |
| `ios/` | Native iOS app written in SwiftUI (multiple screens, background service, CRUD through the API plus on-device SwiftData) |
| `frontend/` | Dynamic web app in HTML, CSS and JavaScript, served by a small Python server that forwards requests to the API |

No templates or third-party frameworks are used.

## How to access and run it

### 1. Get the code
```sh
git clone https://github.com/ussg43/listings.git
cd listings
```
You can also click **Code → Download ZIP** on the GitHub page.

### 2. Start the backend (needed for live data)
Requires Docker Desktop. Full steps are in [`backend/README.md`](backend/README.md). They start PostgreSQL, run the migrations, and serve the API at `http://localhost:8080`.
Check that it's running: open http://localhost:8080/health

### 3. Run the iOS app
Requires a Mac with Xcode 16 or later.
1. Open `ios/Listings.xcodeproj` in Xcode.
2. Choose an iPhone simulator (for example iPhone 16) and press **Run** (⌘R).

Details: [`ios/README.md`](ios/README.md)

### 4. Run the web app
Requires Python 3.
```sh
python3 frontend/serve.py
```
Open http://localhost:5173

Details: [`frontend/README.md`](frontend/README.md)

### Running without the backend
Both the iOS app and the web app show sample listings when the API isn't reachable.
For the web app, use http://localhost:5173/?demo=1

## Team
- Usseinu Gueye
- Kyle Hoot
- Allen
- Litzy Raymundo
