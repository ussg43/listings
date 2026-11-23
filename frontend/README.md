# Listings frontend

From the project root, run:

```sh
python3 frontend/serve.py
```

Open [the marketplace](http://localhost:5173). Use [demo mode](http://localhost:5173/?demo=1) to explore sample listings without the backend. If the live API is unavailable, the browse page shows samples and a retry action.

For live data, follow the [backend setup](../backend/README.md) to migrate PostgreSQL and start Go on port 8080. The frontend server forwards API and photo requests to Go. You can point it at another API origin with `--api http://localhost:8081`.

Live accounts, listings, listing status, and JPEG photos go through the Go API. Search and listing-type filters run in the browser. Saved listings and meetup plans are stored on the current device. Meetup plans do not send requests or notifications. Sample prices and pickup spots illustrate the design. The current API has no fields for those values and no endpoints for messaging, offers, or shared scheduling.

This server binds to loopback for development. The Go API verifies account passwords but provides no server-side session or listing ownership enforcement. The frontend's owner controls are UI affordances. Public hosting requires backend authentication and authorization.
