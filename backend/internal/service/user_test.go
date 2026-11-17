package service

import (
	"context"
	"errors"
	"testing"

	"github.com/ussg43/listings/backend/internal/store"
	"golang.org/x/crypto/bcrypt"
)

type memoryUsers struct {
	user *store.User
}

func (m *memoryUsers) Create(_ context.Context, user *store.User) error {
	if m.user != nil && m.user.Email == user.Email {
		return store.ErrConflict
	}
	copy := *user
	copy.PasswordHash = append([]byte(nil), user.PasswordHash...)
	m.user = &copy
	return nil
}

func (m *memoryUsers) GetByEmail(_ context.Context, email string) (*store.User, error) {
	if m.user == nil || m.user.Email != email {
		return nil, store.ErrNotFound
	}
	return m.user, nil
}

func TestRegisterAndLoginUseHashedPassword(t *testing.T) {
	repository := &memoryUsers{}
	users := NewUserService(repository)
	created, err := users.Register(context.Background(), " User@Example.com ", "correct horse")
	if err != nil {
		t.Fatal(err)
	}
	if created.Email != "user@example.com" {
		t.Fatalf("email = %q", created.Email)
	}
	if repository.user.PasswordHash == nil {
		t.Fatal("stored password hash is empty")
	}
	if err := bcrypt.CompareHashAndPassword(repository.user.PasswordHash, []byte("correct horse")); err != nil {
		t.Fatalf("stored hash does not match password: %v", err)
	}
	if created.PasswordHash != nil {
		t.Fatal("registration response includes password hash")
	}
	loggedIn, err := users.Login(context.Background(), "USER@example.com", "correct horse")
	if err != nil {
		t.Fatal(err)
	}
	if loggedIn.ID != created.ID || loggedIn.PasswordHash != nil {
		t.Fatalf("login response = %#v", loggedIn)
	}
	if _, err := users.Login(context.Background(), created.Email, "wrong password"); !errors.Is(err, ErrInvalidLogin) {
		t.Fatalf("wrong password error = %v, want ErrInvalidLogin", err)
	}
}

func TestRegisterRejectsInvalidCredentials(t *testing.T) {
	users := NewUserService(&memoryUsers{})
	for _, test := range []struct {
		email    string
		password string
	}{
		{email: "person@example.com", password: "short"},
		{email: "Name <person@example.com>", password: "long-enough"},
	} {
		if _, err := users.Register(context.Background(), test.email, test.password); !errors.Is(err, ErrInvalidInput) {
			t.Errorf("Register(%q): error = %v, want ErrInvalidInput", test.email, err)
		}
	}
}
