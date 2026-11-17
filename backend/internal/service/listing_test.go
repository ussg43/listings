package service

import (
	"context"
	"testing"

	"github.com/ussg43/listings/backend/internal/store"
)

type memoryListings struct {
	listings map[string]*store.Listing
}

func (m *memoryListings) Create(_ context.Context, listing *store.Listing) error {
	m.listings[listing.ID] = listing
	return nil
}

func (m *memoryListings) Update(_ context.Context, listing *store.Listing) ([]string, error) {
	stored := m.listings[listing.ID]
	if stored == nil {
		return nil, store.ErrNotFound
	}
	oldPhotos := append([]string(nil), stored.Photos...)
	m.listings[listing.ID] = listing
	return oldPhotos, nil
}

func (m *memoryListings) Delete(_ context.Context, id string) ([]string, error) {
	listing := m.listings[id]
	if listing == nil {
		return nil, store.ErrNotFound
	}
	delete(m.listings, id)
	return listing.Photos, nil
}

func (m *memoryListings) Get(_ context.Context, id string) (*store.Listing, error) {
	listing := m.listings[id]
	if listing == nil {
		return nil, store.ErrNotFound
	}
	copy := *listing
	copy.Photos = append([]string(nil), listing.Photos...)
	return &copy, nil
}

func (m *memoryListings) GetAll(context.Context, string) ([]store.Listing, error) {
	return nil, nil
}

type memoryPhotos struct {
	next    int
	deleted []string
}

func (m *memoryPhotos) Save(context.Context, []byte) (string, error) {
	m.next++
	return "photo-" + string(rune('0'+m.next)), nil
}

func (m *memoryPhotos) Delete(_ context.Context, names []string) error {
	m.deleted = append(m.deleted, names...)
	return nil
}

func TestListingLifecycleAndPhotoReplacement(t *testing.T) {
	repository := &memoryListings{listings: make(map[string]*store.Listing)}
	photos := &memoryPhotos{}
	listings := NewListingService(repository, photos)
	input := ListingInput{
		UserID: "user-1", Title: "Desk", Description: "Wood desk",
		Type: store.ListingSale, Condition: store.ConditionGood, Status: store.StatusAvailable,
	}
	created, err := listings.Create(context.Background(), input, [][]byte{[]byte("jpeg-data")})
	if err != nil {
		t.Fatal(err)
	}
	oldPhoto := created.Photos[0]

	input.Title = "Updated desk"
	input.Status = store.StatusPending
	updated, err := listings.Update(context.Background(), created.ID, input, [][]byte{[]byte("new-jpeg")}, true)
	if err != nil {
		t.Fatal(err)
	}
	if updated.Title != input.Title || updated.Status != store.StatusPending || updated.Photos[0] == oldPhoto {
		t.Fatalf("updated listing = %#v", updated)
	}
	if len(photos.deleted) != 1 || photos.deleted[0] != oldPhoto {
		t.Fatalf("deleted photos = %v, want replaced photo %q", photos.deleted, oldPhoto)
	}

	if err := listings.Delete(context.Background(), created.ID); err != nil {
		t.Fatal(err)
	}
	if len(photos.deleted) != 2 || photos.deleted[1] != updated.Photos[0] {
		t.Fatalf("deleted photos after listing removal = %v", photos.deleted)
	}
}
