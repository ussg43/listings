package photos

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestLocalServiceStoresAndDeletesJPEG(t *testing.T) {
	directory := t.TempDir()
	service, err := NewLocalService(directory)
	if err != nil {
		t.Fatal(err)
	}

	imageData := image.NewRGBA(image.Rect(0, 0, 2, 2))
	imageData.Set(0, 0, color.White)
	var content bytes.Buffer
	if err := jpeg.Encode(&content, imageData, nil); err != nil {
		t.Fatal(err)
	}
	name, err := service.Save(context.Background(), content.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	file, err := service.Open(name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := io.ReadAll(file); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := service.Delete(context.Background(), []string{name}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(directory, name)); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("photo still exists after deletion: %v", err)
	}
}

func TestLocalServiceRejectsNonJPEGAndUnsafeNames(t *testing.T) {
	service, err := NewLocalService(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := service.Save(context.Background(), []byte("not an image")); err == nil {
		t.Fatal("invalid image accepted")
	}
	if _, err := service.Open("..\\secret.jpg"); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("unsafe photo name error = %v, want not found", err)
	}
}
