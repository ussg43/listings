CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS listings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    title VARCHAR(160) NOT NULL,
    description VARCHAR(5000) NOT NULL DEFAULT '',
    listing_type TEXT NOT NULL CHECK (listing_type IN ('sale', 'trade', 'giveaway')),
    condition TEXT NOT NULL CHECK (condition IN ('new', 'great', 'good', 'fair', 'poor')),
    status TEXT NOT NULL CHECK (status IN ('available', 'pending', 'sold')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS listings_created_at_idx ON listings (created_at DESC);
CREATE INDEX IF NOT EXISTS listings_user_id_idx ON listings (user_id);

CREATE TABLE IF NOT EXISTS listing_photos (
    listing_id TEXT NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    position SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 4),
    filename TEXT NOT NULL UNIQUE,
    PRIMARY KEY (listing_id, position)
);
