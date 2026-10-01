// Remove the background of one image — Go 1.20+, standard library only.
//
//	PIXMILLER_API_KEY=... go run . product.jpg [out.png]
//
// Env: PIXMILLER_API_BASE (default https://api.pixmiller.com), PIXMILLER_SIZE (default auto).
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

var (
	apiBase = env("PIXMILLER_API_BASE", "https://api.pixmiller.com") // was https://api.remove.bg
	apiKey  = os.Getenv("PIXMILLER_API_KEY")
	size    = env("PIXMILLER_SIZE", "auto") // preview/small/regular = free, watermarked
)

// apiError mirrors remove.bg's envelope: {"errors":[{"code":"…","title":"…"}]}
type apiError struct {
	Errors []struct {
		Code  string `json:"code"`
		Title string `json:"title"`
	} `json:"errors"`
}

func removeBackground(path string) (*http.Response, []byte, error) {
	image, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, err
	}
	client := &http.Client{Timeout: 120 * time.Second}
	for attempt := 0; ; attempt++ {
		var body bytes.Buffer
		form := multipart.NewWriter(&body)
		part, _ := form.CreateFormFile("image_file", filepath.Base(path))
		part.Write(image)
		form.WriteField("size", size)
		form.Close()

		req, _ := http.NewRequest(http.MethodPost, apiBase+"/v1.0/removebg", &body)
		req.Header.Set("X-Api-Key", apiKey)
		req.Header.Set("Content-Type", form.FormDataContentType())

		resp, err := client.Do(req)
		if err != nil {
			return nil, nil, err
		}
		data, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, nil, err
		}
		if resp.StatusCode == http.StatusTooManyRequests && attempt < 3 {
			wait, convErr := strconv.Atoi(resp.Header.Get("Retry-After"))
			if convErr != nil {
				wait = 5
			}
			fmt.Fprintf(os.Stderr, "rate limited, retrying in %ds\n", wait)
			time.Sleep(time.Duration(wait) * time.Second)
			continue
		}
		return resp, data, nil
	}
}

func main() {
	if apiKey == "" {
		fmt.Fprintln(os.Stderr, "Set PIXMILLER_API_KEY (https://pixmiller.com/en/users/~api/)")
		os.Exit(2)
	}
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: go run . input-image [output.png]")
		os.Exit(2)
	}
	output := "out.png"
	if len(os.Args) > 2 {
		output = os.Args[2]
	}

	resp, data, err := removeBackground(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
	if resp.StatusCode != http.StatusOK {
		var e apiError
		if json.Unmarshal(data, &e) == nil && len(e.Errors) > 0 {
			fmt.Fprintf(os.Stderr, "error: HTTP %d %s: %s\n", resp.StatusCode, e.Errors[0].Code, e.Errors[0].Title)
		} else {
			fmt.Fprintf(os.Stderr, "error: HTTP %d %s\n", resp.StatusCode, data)
		}
		os.Exit(1)
	}
	if err := os.WriteFile(output, data, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
	h := resp.Header
	fmt.Printf("saved %s · %sx%s px · credits charged: %s · type: %s\n",
		output, h.Get("X-Width"), h.Get("X-Height"), h.Get("X-Credits-Charged"), h.Get("X-Type"))
}
