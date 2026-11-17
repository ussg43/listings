package main

import (
	"context"

	"github.com/ussg43/listings/backend/internal/service"
	"github.com/ussg43/listings/backend/internal/store"
)

func (app *application) CreateUser(ctx context.Context, email, password string) (*store.User, error) {
	return app.users.Register(ctx, email, password)
}

func (app *application) Login(ctx context.Context, email, password string) (*store.User, error) {
	return app.users.Login(ctx, email, password)
}

func (app *application) CreateListing(ctx context.Context, input service.ListingInput, files [][]byte) (*store.Listing, error) {
	return app.listings.Create(ctx, input, files)
}

func (app *application) UpdateListing(ctx context.Context, id string, input service.ListingInput, files [][]byte, replacePhotos bool) (*store.Listing, error) {
	return app.listings.Update(ctx, id, input, files, replacePhotos)
}

func (app *application) DeleteListing(ctx context.Context, id string) error {
	return app.listings.Delete(ctx, id)
}

func (app *application) GetListing(ctx context.Context, id string) (*store.Listing, error) {
	return app.listings.Get(ctx, id)
}

func (app *application) GetListings(ctx context.Context, userID string) ([]store.Listing, error) {
	return app.listings.GetAll(ctx, userID)
}
