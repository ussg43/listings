package main

import (
	"log"
	"net/url"
	"strings"

	"github.com/ussg43/listings/backend/internal/db"
	"github.com/ussg43/listings/backend/internal/env"
	"github.com/ussg43/listings/backend/internal/photos"
	"github.com/ussg43/listings/backend/internal/service"
	"github.com/ussg43/listings/backend/internal/store"
)

func main() {
	cfg := config{
		addr:       env.GetString("ADDR", ":8080"),
		apiBaseURL: strings.TrimRight(env.GetString("API_BASE_URL", ""), "/"),
	}
	if cfg.apiBaseURL != "" {
		baseURL, err := url.Parse(cfg.apiBaseURL)
		if err != nil {
			log.Fatalf("invalid API_BASE_URL: %v", err)
		}
		if (baseURL.Scheme != "http" && baseURL.Scheme != "https") || baseURL.Host == "" {
			log.Fatal("invalid API_BASE_URL: expected an absolute HTTP or HTTPS URL")
		}
	}

	db, err := db.New()
	if err != nil {
		log.Fatalf("error connecting to database: %v", err)
	}
	defer db.Close()

	storage := store.NewStorage(db)
	photoService, err := photos.NewLocalService(env.GetString("PHOTO_DIR", "data/photos"))
	if err != nil {
		log.Fatalf("error initializing photo storage: %v", err)
	}

	app := &application{
		cfg:      cfg,
		db:       db,
		store:    storage,
		users:    service.NewUserService(storage.Users),
		listings: service.NewListingService(storage.Listings, photoService),
		photos:   photoService,
	}

	mux := app.mount()
	log.Fatal(app.run(mux))
}
