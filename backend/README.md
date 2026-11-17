# Listings backend

Go HTTP API for user accounts and public item listings. Listing routes do not
require authentication; login verifies a password and returns the user, but does
not issue a token or create a session. Because there is no authorization, any
caller can edit or delete any listing; listing creation accepts the owner's
existing `user_id` directly.

## Run

Set `DB_CONNECTION` to a PostgreSQL connection string. Run the SQL migrations
using `make migrate-up` before starting the API. Optional settings are `ADDR`
(default `:8080`), `API_BASE_URL` (used to construct absolute photo URLs), and
`PHOTO_DIR` (default `data/photos`). No `.env` file is required or created.

```powershell
$env:DB_CONNECTION = "postgres://user:password@localhost:5432/listings?sslmode=disable"
$env:API_BASE_URL = "http://localhost:8080"
make migrate-up
go run .\cmd\api
```

`make migrate-up` uses `DB_MIGRATION_ADDR`, which defaults to `DB_CONNECTION`.
The `migrate` CLI must be installed for migration targets.

## Docker

These steps run PostgreSQL, apply the schema migrations, and launch the API
using Docker Desktop. Start Docker Desktop first, wait for its Linux engine to
be ready, and verify that `docker info` succeeds. Run the commands from the
`backend` directory in PowerShell.

Create a Docker network and start a development PostgreSQL database:

```powershell
docker network create listings-net
docker volume create listings-postgres
docker run -d --name listings-db --network listings-net `
  -e POSTGRES_USER=listings `
  -e POSTGRES_PASSWORD=listings-dev-password `
  -e POSTGRES_DB=listings `
  -v listings-postgres:/var/lib/postgresql/data `
  postgres:17-alpine
```

Wait until PostgreSQL is accepting connections:

```powershell
do {
  Start-Sleep -Seconds 2
  docker exec listings-db pg_isready -U listings -d listings
} until ($LASTEXITCODE -eq 0)
```

Apply migrations using the official migration image. The schema files are
mounted read-only; no migration executable is needed on the host:

```powershell
$migrationPath = (Resolve-Path .\cmd\migrations\migrate).Path
docker run --rm --network listings-net `
  -v "${migrationPath}:/migrations:ro" `
  migrate/migrate:v4.18.3 `
  -path=/migrations `
  -database="postgres://listings:listings-dev-password@listings-db:5432/listings?sslmode=disable" `
  up
```

Build and run the API image:

```powershell
docker build -t listings-api:local .
docker volume create listings-photos
docker run -d --name listings-api --network listings-net -p 8080:8080 `
  -e DB_CONNECTION="postgres://listings:listings-dev-password@listings-db:5432/listings?sslmode=disable" `
  -e API_BASE_URL="http://localhost:8080" `
  -v listings-photos:/app/data/photos `
  listings-api:local
```

Check the health endpoint and view logs:

```powershell
Invoke-RestMethod http://localhost:8080/health
docker logs listings-api
```

The API is available at `http://localhost:8080`. For example, register a
development user:

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:8080/v1/users `
  -ContentType "application/json" `
  -Body '{"email":"test@example.com","password":"development-password"}'
```

To stop the API and database containers:

```powershell
docker stop listings-api listings-db
```

The named volumes retain the database and uploaded photos between runs. These
example credentials are for local testing only; use appropriately secured
secrets and database settings outside development.

## API

- `POST /v1/users` — JSON `{ "email": "...", "password": "..." }`; passwords
  must be 8–72 bytes and are stored as bcrypt hashes.
- `POST /v1/login` — same JSON body; verifies credentials and returns the user.
- `POST /v1/listings` — multipart fields `user_id`, `title`, `description`,
  `type` (`sale`, `trade`, `giveaway`), `condition` (`new`, `great`, `good`,
  `fair`, `poor`), optional `status` (`available`, `pending`, `sold`), and up to
  five repeated `photos` JPEG file fields (10 MB each).
- `GET /v1/listings` — list public listings; optional `user_id` filter.
- `GET /v1/listings/{id}` — get a public listing.
- `PUT /v1/listings/{id}` — multipart fields `title`, `description`, `type`,
  `condition`, and `status`; upload `photos` to replace the current photos or
  set `clear_photos=true` to remove them. Listing owner is unchanged.
- `DELETE /v1/listings/{id}` — delete the listing and its stored photos.
- `GET /v1/photos/{filename}` — retrieve a listing photo.
