package main

import (
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jmoiron/sqlx"
	"github.com/ussg43/listings/backend/internal/photos"
	"github.com/ussg43/listings/backend/internal/service"
	"github.com/ussg43/listings/backend/internal/store"
)

type config struct {
	addr       string
	apiBaseURL string
}

type application struct {
	cfg      config
	db       *sqlx.DB
	store    store.Storage
	users    *service.UserService
	listings *service.ListingService
	photos   *photos.LocalService
}

func (app *application) mount() http.Handler {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Get("/health", app.healthCheckHandler)
	r.Route("/v1", func(r chi.Router) {
		r.Post("/users", app.createUserHandler)
		r.Post("/login", app.loginHandler)

		r.Get("/listings", app.getListingsHandler)
		r.Post("/listings", app.createListingHandler)
		r.Get("/listings/{id}", app.getListingHandler)
		r.Put("/listings/{id}", app.updateListingHandler)
		r.Delete("/listings/{id}", app.deleteListingHandler)

		r.Get("/photos/{filename}", app.getPhotoHandler)
	})

	return r
}

func (app *application) run(mux http.Handler) error {
	srv := &http.Server{
		Addr:         app.cfg.addr,
		Handler:      mux,
		WriteTimeout: time.Second * 30,
		ReadTimeout:  time.Second * 10,
		IdleTimeout:  time.Minute,
	}

	log.Printf("Server has started at %s", app.cfg.addr)
	return srv.ListenAndServe()
}
