package service

import (
	"context"
	"errors"
	"net/mail"
	"strings"

	"github.com/ussg43/listings/backend/internal/store"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidInput   = errors.New("invalid input")
	ErrInvalidLogin   = errors.New("invalid email or password")
	ErrInvalidListing = errors.New("invalid listing")
)

type UserService struct {
	store interface {
		Create(context.Context, *store.User) error
		GetByEmail(context.Context, string) (*store.User, error)
	}
}

func NewUserService(users interface {
	Create(context.Context, *store.User) error
	GetByEmail(context.Context, string) (*store.User, error)
}) *UserService {
	return &UserService{store: users}
}

func (s *UserService) Register(ctx context.Context, email, password string) (*store.User, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	address, err := mail.ParseAddress(email)
	if err != nil || address.Address != email || len(email) > 254 || len(password) < 8 || len(password) > 72 {
		return nil, ErrInvalidInput
	}
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	id, err := newID()
	if err != nil {
		return nil, err
	}
	user := &store.User{ID: id, Email: email, PasswordHash: passwordHash}
	if err := s.store.Create(ctx, user); err != nil {
		return nil, err
	}
	user.PasswordHash = nil
	return user, nil
}

func (s *UserService) Login(ctx context.Context, email, password string) (*store.User, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	user, err := s.store.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return nil, ErrInvalidLogin
		}
		return nil, err
	}
	if err := bcrypt.CompareHashAndPassword(user.PasswordHash, []byte(password)); err != nil {
		return nil, ErrInvalidLogin
	}
	user.PasswordHash = nil
	return user, nil
}
