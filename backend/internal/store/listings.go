package store

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jmoiron/sqlx"
)

type ListingType string

const (
	ListingSale     ListingType = "sale"
	ListingTrade    ListingType = "trade"
	ListingGiveaway ListingType = "giveaway"
)

type Condition string

const (
	ConditionNew   Condition = "new"
	ConditionGreat Condition = "great"
	ConditionGood  Condition = "good"
	ConditionFair  Condition = "fair"
	ConditionPoor  Condition = "poor"
)

type ListingStatus string

const (
	StatusAvailable ListingStatus = "available"
	StatusPending   ListingStatus = "pending"
	StatusSold      ListingStatus = "sold"
)

type Listing struct {
	ID          string        `json:"id" db:"id"`
	UserID      string        `json:"user_id" db:"user_id"`
	Title       string        `json:"title" db:"title"`
	Description string        `json:"description" db:"description"`
	Type        ListingType   `json:"type" db:"listing_type"`
	Condition   Condition     `json:"condition" db:"condition"`
	Status      ListingStatus `json:"status" db:"status"`
	Photos      []string      `json:"photos" db:"-"`
	CreatedAt   time.Time     `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time     `json:"updated_at" db:"updated_at"`
}

type ListingStore struct {
	db *sqlx.DB
}

const listingSelect = `
	SELECT id, user_id, title, description, listing_type, condition, status, created_at, updated_at
	FROM listings`

func (s *ListingStore) Create(ctx context.Context, listing *Listing) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(ctx, `
		INSERT INTO listings (id, user_id, title, description, listing_type, condition, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		listing.ID, listing.UserID, listing.Title, listing.Description, listing.Type,
		listing.Condition, listing.Status, listing.CreatedAt, listing.UpdatedAt)
	if isForeignKeyViolation(err) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if err := insertPhotos(ctx, tx, listing); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *ListingStore) Update(ctx context.Context, listing *Listing) ([]string, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	oldPhotos, err := getPhotoNames(ctx, tx, listing.ID)
	if err != nil {
		return nil, err
	}
	result, err := tx.ExecContext(ctx, `
		UPDATE listings SET title = $1, description = $2, listing_type = $3,
			condition = $4, status = $5, updated_at = $6
		WHERE id = $7`,
		listing.Title, listing.Description, listing.Type, listing.Condition,
		listing.Status, listing.UpdatedAt, listing.ID)
	if err != nil {
		return nil, err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, err
	}
	if rowsAffected == 0 {
		return nil, ErrNotFound
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM listing_photos WHERE listing_id = $1`, listing.ID); err != nil {
		return nil, err
	}
	if err := insertPhotos(ctx, tx, listing); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return oldPhotos, nil
}

func (s *ListingStore) Delete(ctx context.Context, id string) ([]string, error) {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	names, err := getPhotoNames(ctx, tx, id)
	if err != nil {
		return nil, err
	}
	result, err := tx.ExecContext(ctx, `DELETE FROM listings WHERE id = $1`, id)
	if err != nil {
		return nil, err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, err
	}
	if rowsAffected == 0 {
		return nil, ErrNotFound
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return names, nil
}

func (s *ListingStore) Get(ctx context.Context, id string) (*Listing, error) {
	listing := &Listing{Photos: make([]string, 0)}
	err := s.db.GetContext(ctx, listing, listingSelect+` WHERE id = $1`, id)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	listing.Photos, err = s.getPhotos(ctx, listing.ID)
	return listing, err
}

func (s *ListingStore) GetAll(ctx context.Context, userID string) ([]Listing, error) {
	query := listingSelect
	args := []any{}
	if userID != "" {
		query += ` WHERE user_id = $1`
		args = append(args, userID)
	}
	query += ` ORDER BY created_at DESC`
	listings := make([]Listing, 0)
	if err := s.db.SelectContext(ctx, &listings, query, args...); err != nil {
		return nil, err
	}
	for i := range listings {
		photos, err := s.getPhotos(ctx, listings[i].ID)
		if err != nil {
			return nil, err
		}
		listings[i].Photos = photos
	}
	return listings, nil
}
