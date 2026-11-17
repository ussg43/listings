package photos

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg"
	"io"
	"os"
	"path/filepath"
)

type LocalService struct {
	directory string
}

func NewLocalService(directory string) (*LocalService, error) {
	if err := os.MkdirAll(directory, 0o750); err != nil {
		return nil, fmt.Errorf("create photo directory: %w", err)
	}
	absolute, err := filepath.Abs(directory)
	if err != nil {
		return nil, fmt.Errorf("resolve photo directory: %w", err)
	}
	return &LocalService{directory: absolute}, nil
}

func (s *LocalService) Save(ctx context.Context, content []byte) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	if len(content) == 0 {
		return "", errors.New("photo is empty")
	}
	_, format, err := image.DecodeConfig(bytes.NewReader(content))
	if err != nil || format != "jpeg" {
		return "", errors.New("photo must be a valid JPEG")
	}
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		return "", fmt.Errorf("generate photo name: %w", err)
	}
	name := hex.EncodeToString(random) + ".jpg"
	path := filepath.Join(s.directory, name)
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o640)
	if err != nil {
		return "", fmt.Errorf("create photo: %w", err)
	}
	if _, err := file.Write(content); err != nil {
		_ = file.Close()
		_ = os.Remove(path)
		return "", fmt.Errorf("write photo: %w", err)
	}
	if err := file.Close(); err != nil {
		_ = os.Remove(path)
		return "", fmt.Errorf("close photo: %w", err)
	}
	return name, nil
}

func (s *LocalService) Delete(ctx context.Context, names []string) error {
	for _, name := range names {
		if err := ctx.Err(); err != nil {
			return err
		}
		if filepath.Base(name) != name || filepath.Ext(name) != ".jpg" {
			return errors.New("invalid photo name")
		}
		err := os.Remove(filepath.Join(s.directory, name))
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("delete photo %s: %w", name, err)
		}
	}
	return nil
}

func (s *LocalService) Open(name string) (io.ReadCloser, error) {
	if filepath.Base(name) != name || filepath.Ext(name) != ".jpg" {
		return nil, os.ErrNotExist
	}
	return os.Open(filepath.Join(s.directory, name))
}
