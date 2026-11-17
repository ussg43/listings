package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/ussg43/listings/backend/internal/store"
)

type ListingInput struct {
	UserID      string
	Title       string
	Description string
	Type        store.ListingType
	Condition   store.Condition
	Status      store.ListingStatus
}

type ListingService struct {
	store interface {
		Create(context.Context, *store.Listing) error
		Update(context.Context, *store.Listing) ([]string, error)
		Delete(context.Context, string) ([]string, error)
		Get(context.Context, string) (*store.Listing, error)
		GetAll(context.Context, string) ([]store.Listing, error)
	}
	photos interface {
		Save(context.Context, []byte) (string, error)
		Delete(context.Context, []string) error
	}
}

func NewListingService(listings interface {
	Create(context.Context, *store.Listing) error
	Update(context.Context, *store.Listing) ([]string, error)
	Delete(context.Context, string) ([]string, error)
	Get(context.Context, string) (*store.Listing, error)
	GetAll(context.Context, string) ([]store.Listing, error)
}, photoService interface {
	Save(context.Context, []byte) (string, error)
	Delete(context.Context, []string) error
}) *ListingService {
	return &ListingService{store: listings, photos: photoService}
}

func (s *ListingService) Create(ctx context.Context, input ListingInput, jpegPhotos [][]byte) (*store.Listing, error) {
	if len(jpegPhotos) > 5 {
		return nil, ErrInvalidListing
	}
	names, err := s.savePhotos(ctx, jpegPhotos)
	if err != nil {
		return nil, err
	}
	if err := validateListing(input, len(names)); err != nil {
		return nil, errors.Join(err, s.photos.Delete(ctx, names))
	}
	id, err := newID()
	if err != nil {
		return nil, errors.Join(err, s.photos.Delete(ctx, names))
	}
	now := time.Now().UTC()
	listing := &store.Listing{
		ID: id, UserID: input.UserID, Title: strings.TrimSpace(input.Title), Description: input.Description,
		Type: input.Type, Condition: input.Condition, Status: input.Status,
		Photos: names, CreatedAt: now, UpdatedAt: now,
	}
	if err := s.store.Create(ctx, listing); err != nil {
		return nil, errors.Join(err, s.photos.Delete(ctx, names))
	}
	return listing, nil
}

func (s *ListingService) Update(ctx context.Context, id string, input ListingInput, jpegPhotos [][]byte, replacePhotos bool) (*store.Listing, error) {
	listing, err := s.store.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if input.Status == "" {
		input.Status = listing.Status
	}
	if replacePhotos && len(jpegPhotos) > 5 {
		return nil, ErrInvalidListing
	}
	newPhotos := listing.Photos
	if replacePhotos {
		newPhotos, err = s.savePhotos(ctx, jpegPhotos)
		if err != nil {
			return nil, err
		}
	}
	input.UserID = listing.UserID
	if err := validateListing(input, len(newPhotos)); err != nil {
		if replacePhotos {
			return nil, errors.Join(err, s.photos.Delete(ctx, newPhotos))
		}
		return nil, err
	}
	oldPhotos := listing.Photos
	listing.Title = strings.TrimSpace(input.Title)
	listing.Description = input.Description
	listing.Type = input.Type
	listing.Condition = input.Condition
	listing.Status = input.Status
	listing.Photos = newPhotos
	listing.UpdatedAt = time.Now().UTC()
	replaced, err := s.store.Update(ctx, listing)
	if err != nil {
		if replacePhotos {
			return nil, errors.Join(err, s.photos.Delete(ctx, newPhotos))
		}
		return nil, err
	}
	if replacePhotos {
		oldPhotos = replaced
		if err := s.photos.Delete(ctx, oldPhotos); err != nil {
			return nil, err
		}
	}
	return listing, nil
}

func (s *ListingService) Delete(ctx context.Context, id string) error {
	names, err := s.store.Delete(ctx, id)
	if err != nil {
		return err
	}
	return s.photos.Delete(ctx, names)
}

func (s *ListingService) Get(ctx context.Context, id string) (*store.Listing, error) {
	return s.store.Get(ctx, id)
}

func (s *ListingService) GetAll(ctx context.Context, userID string) ([]store.Listing, error) {
	return s.store.GetAll(ctx, userID)
}

func validateListing(input ListingInput, photoCount int) error {
	if strings.TrimSpace(input.UserID) == "" ||
		strings.TrimSpace(input.Title) == "" ||
		len(input.Title) > 160 ||
		len(input.Description) > 5000 ||
		(input.Type != store.ListingSale && input.Type != store.ListingTrade && input.Type != store.ListingGiveaway) ||
		(input.Condition != store.ConditionNew && input.Condition != store.ConditionGreat &&
			input.Condition != store.ConditionGood && input.Condition != store.ConditionFair && input.Condition != store.ConditionPoor) ||
		(input.Status != store.StatusAvailable && input.Status != store.StatusPending && input.Status != store.StatusSold) ||
		photoCount > 5 {
		return ErrInvalidListing
	}
	return nil
}

func (s *ListingService) savePhotos(ctx context.Context, files [][]byte) ([]string, error) {
	names := make([]string, 0, len(files))
	for _, file := range files {
		name, err := s.photos.Save(ctx, file)
		if err != nil {
			if cleanupErr := s.photos.Delete(ctx, names); cleanupErr != nil {
				return nil, errors.Join(err, cleanupErr)
			}
			return nil, err
		}
		names = append(names, name)
	}
	return names, nil
}
