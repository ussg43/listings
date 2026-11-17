package db

import (
	"context"
	"errors"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/jmoiron/sqlx"
	"github.com/ussg43/listings/backend/internal/env"
)

func New() (*sqlx.DB, error) {
	connection := env.GetString("DB_CONNECTION", "")
	if connection == "" {
		return nil, errors.New("DB_CONNECTION is required")
	}

	db, err := sqlx.Connect("pgx", connection)
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, err
	}

	return db, nil
}
