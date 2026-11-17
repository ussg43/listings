package main

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg"
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/ussg43/listings/backend/internal/service"
	"github.com/ussg43/listings/backend/internal/store"
)

const (
	maxRequestBytes = 52 << 20
	maxPhotoBytes   = 10 << 20
)

type credentialsPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (app *application) healthCheckHandler(w http.ResponseWriter, _ *http.Request) {
	if err := app.JSONresponse(w, http.StatusOK, map[string]string{"status": "ok"}); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) createUserHandler(w http.ResponseWriter, r *http.Request) {
	var payload credentialsPayload
	if err := ReadJSON(w, r, &payload); err != nil {
		WriteJSONErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	user, err := app.CreateUser(r.Context(), payload.Email, payload.Password)
	if err != nil {
		if errors.Is(err, service.ErrInvalidInput) {
			WriteJSONErr(w, http.StatusBadRequest, err.Error())
		} else if errors.Is(err, store.ErrConflict) {
			WriteJSONErr(w, http.StatusConflict, "email already registered")
		} else {
			WriteJSONErr(w, http.StatusInternalServerError, "could not create user")
		}
		return
	}
	if err := app.JSONresponse(w, http.StatusCreated, user); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) loginHandler(w http.ResponseWriter, r *http.Request) {
	var payload credentialsPayload
	if err := ReadJSON(w, r, &payload); err != nil {
		WriteJSONErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	user, err := app.Login(r.Context(), payload.Email, payload.Password)
	if err != nil {
		if errors.Is(err, service.ErrInvalidLogin) {
			WriteJSONErr(w, http.StatusUnauthorized, err.Error())
		} else {
			WriteJSONErr(w, http.StatusInternalServerError, "could not log in")
		}
		return
	}
	if err := app.JSONresponse(w, http.StatusOK, user); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) createListingHandler(w http.ResponseWriter, r *http.Request) {
	input, files, err := ReadListingForm(w, r, false)
	if err != nil {
		WriteJSONErr(w, http.StatusBadRequest, err.Error())
		return
	}
	listing, err := app.CreateListing(r.Context(), input, files)
	if err != nil {
		app.writeListingError(w, err)
		return
	}
	app.setPhotoURLs(listing)
	if err := app.JSONresponse(w, http.StatusCreated, listing); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) updateListingHandler(w http.ResponseWriter, r *http.Request) {
	input, files, err := ReadListingForm(w, r, true)
	if err != nil {
		WriteJSONErr(w, http.StatusBadRequest, err.Error())
		return
	}
	replacePhotos := len(files) > 0 || r.FormValue("clear_photos") == "true"
	listing, err := app.UpdateListing(r.Context(), chi.URLParam(r, "id"), input, files, replacePhotos)
	if err != nil {
		app.writeListingError(w, err)
		return
	}
	app.setPhotoURLs(listing)
	if err := app.JSONresponse(w, http.StatusOK, listing); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) getListingsHandler(w http.ResponseWriter, r *http.Request) {
	listings, err := app.GetListings(r.Context(), r.URL.Query().Get("user_id"))
	if err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, "could not load listings")
		return
	}
	for i := range listings {
		app.setPhotoURLs(&listings[i])
	}
	if err := app.JSONresponse(w, http.StatusOK, listings); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) getListingHandler(w http.ResponseWriter, r *http.Request) {
	listing, err := app.GetListing(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		app.writeListingError(w, err)
		return
	}
	app.setPhotoURLs(listing)
	if err := app.JSONresponse(w, http.StatusOK, listing); err != nil {
		WriteJSONErr(w, http.StatusInternalServerError, err.Error())
	}
}

func (app *application) deleteListingHandler(w http.ResponseWriter, r *http.Request) {
	if err := app.DeleteListing(r.Context(), chi.URLParam(r, "id")); err != nil {
		app.writeListingError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (app *application) getPhotoHandler(w http.ResponseWriter, r *http.Request) {
	file, err := app.photos.Open(chi.URLParam(r, "filename"))
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer file.Close()
	w.Header().Set("Content-Type", "image/jpeg")
	w.Header().Set("Cache-Control", "public, max-age=86400")
	if _, err := io.Copy(w, file); err != nil {
		fmt.Printf("write photo response: %v\n", err)
	}
}

func ReadListingForm(w http.ResponseWriter, r *http.Request, update bool) (service.ListingInput, [][]byte, error) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBytes)
	if err := r.ParseMultipartForm(maxRequestBytes); err != nil {
		return service.ListingInput{}, nil, errors.New("expected multipart form with fields and JPEG photos")
	}
	if r.MultipartForm != nil {
		defer r.MultipartForm.RemoveAll()
	}
	input := service.ListingInput{
		UserID:      strings.TrimSpace(r.FormValue("user_id")),
		Title:       strings.TrimSpace(r.FormValue("title")),
		Description: r.FormValue("description"),
		Type:        store.ListingType(strings.ToLower(strings.TrimSpace(r.FormValue("type")))),
		Condition:   store.Condition(strings.ToLower(strings.TrimSpace(r.FormValue("condition")))),
		Status:      store.ListingStatus(strings.ToLower(strings.TrimSpace(r.FormValue("status")))),
	}
	files := r.MultipartForm.File["photos"]
	if len(files) > 5 {
		return service.ListingInput{}, nil, errors.New("at most 5 photos are allowed")
	}
	contents := make([][]byte, 0, len(files))
	for _, header := range files {
		if header.Size > maxPhotoBytes {
			return service.ListingInput{}, nil, errors.New("each photo must be 10 MB or smaller")
		}
		file, err := header.Open()
		if err != nil {
			return service.ListingInput{}, nil, errors.New("could not read uploaded photo")
		}
		content, err := io.ReadAll(io.LimitReader(file, maxPhotoBytes+1))
		closeErr := file.Close()
		if err != nil {
			return service.ListingInput{}, nil, err
		}
		if closeErr != nil {
			return service.ListingInput{}, nil, closeErr
		}
		if len(content) > maxPhotoBytes {
			return service.ListingInput{}, nil, errors.New("each photo must be 10 MB or smaller")
		}
		_, format, err := image.DecodeConfig(bytes.NewReader(content))
		if err != nil || format != "jpeg" {
			return service.ListingInput{}, nil, errors.New("photos must be valid JPEG images")
		}
		contents = append(contents, content)
	}
	if update {
		if input.Title == "" || input.Type == "" || input.Condition == "" {
			return service.ListingInput{}, nil, errors.New("title, type, and condition are required")
		}
	} else if input.UserID == "" || input.Title == "" || input.Type == "" || input.Condition == "" {
		return service.ListingInput{}, nil, errors.New("user_id, title, type, and condition are required")
	}
	if !update && input.Status == "" {
		input.Status = store.StatusAvailable
	}
	return input, contents, nil
}

func (app *application) setPhotoURLs(listing *store.Listing) {
	for i, name := range listing.Photos {
		path := "/v1/photos/" + name
		if app.cfg.apiBaseURL != "" {
			path = app.cfg.apiBaseURL + path
		}
		listing.Photos[i] = path
	}
}

func (app *application) writeListingError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, store.ErrNotFound):
		WriteJSONErr(w, http.StatusNotFound, "listing or user not found")
	case errors.Is(err, service.ErrInvalidListing):
		WriteJSONErr(w, http.StatusBadRequest, err.Error())
	default:
		WriteJSONErr(w, http.StatusInternalServerError, "could not process listing")
	}
}
