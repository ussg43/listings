package store

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/jmoiron/sqlx"
)

type User struct {
	ID           string    `json:"id" db:"id"`
	Email        string    `json:"email" db:"email"`
	PasswordHash []byte    `json:"-" db:"password_hash"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type UserStore struct {
	db *sqlx.DB
}

func (s *UserStore) Create(ctx context.Context, user *User) error {
	err := s.db.QueryRowxContext(ctx,
		`INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3) RETURNING created_at`,
		user.ID, user.Email, user.PasswordHash,
	).Scan(&user.CreatedAt)
	if isUniqueViolation(err) {
		return ErrConflict
	}
	return err
}

func (s *UserStore) GetByEmail(ctx context.Context, email string) (*User, error) {
	user := &User{}
	err := s.db.GetContext(ctx, user,
		`SELECT id, email, password_hash, created_at FROM users WHERE email = $1`, email)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return user, nil
}
