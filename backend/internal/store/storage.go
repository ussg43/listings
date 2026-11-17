package store

import (
	"context"
	"database/sql"
	"errors"

	"github.com/jmoiron/sqlx"
)

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("already exists")
)

type Storage struct {
	Users interface {
		Create(ctx context.Context, user *User) error
		GetByEmail(ctx context.Context, email string) (*User, error)
	}
	Listings interface {
		Create(ctx context.Context, listing *Listing) error
		Update(ctx context.Context, listing *Listing) ([]string, error)
		Delete(ctx context.Context, id string) ([]string, error)
		Get(ctx context.Context, id string) (*Listing, error)
		GetAll(ctx context.Context, userID string) ([]Listing, error)
	}
}

func NewStorage(db *sqlx.DB) Storage {
	return Storage{
		Users:    &UserStore{db: db},
		Listings: &ListingStore{db: db},
	}
}

func isUniqueViolation(err error) bool {
	var state interface{ SQLState() string }
	return errors.As(err, &state) && state.SQLState() == "23505"
}

func isForeignKeyViolation(err error) bool {
	var state interface{ SQLState() string }
	return errors.As(err, &state) && state.SQLState() == "23503"
}

func getPhotoNames(ctx context.Context, tx *sqlx.Tx, id string) ([]string, error) {
	names := make([]string, 0)
	err := tx.SelectContext(ctx, &names,
		`SELECT filename FROM listing_photos WHERE listing_id = $1 ORDER BY position`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return names, nil
	}
	return names, err
}

func (s *ListingStore) getPhotos(ctx context.Context, id string) ([]string, error) {
	names := make([]string, 0)
	err := s.db.SelectContext(ctx, &names,
		`SELECT filename FROM listing_photos WHERE listing_id = $1 ORDER BY position`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return names, nil
	}
	return names, err
}

func insertPhotos(ctx context.Context, tx *sqlx.Tx, listing *Listing) error {
	for i, filename := range listing.Photos {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO listing_photos (listing_id, position, filename) VALUES ($1, $2, $3)`,
			listing.ID, i, filename,
		); err != nil {
			return err
		}
	}
	return nil
}
