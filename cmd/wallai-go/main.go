// wallai-go - generate wallpapers via Pollinations API
//
// Usage: wallai-go -p "prompt" [-im model] [-x n] [-o dir] [-w]
// Dependencies: termux-wallpaper (optional)
// Output: saves images to the specified directory and sets the wallpaper
// TAG: wallpaper
// TAG: go

package main

import (
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	prompt := flag.String("p", "", "Prompt text")
	tag := flag.String("t", "", "Tag to append to the prompt")
	style := flag.String("s", "", "Visual style")
	mood := flag.String("m", "", "Mood descriptor")
	negative := flag.String("n", "", "Negative prompt")
	model := flag.String("im", "flux", "Image model")
	randomModel := flag.Bool("r", false, "Pick random model")
	verbose := flag.Bool("v", false, "Verbose output")
	seed := flag.Int64("seed", time.Now().Unix(), "Random seed")
	count := flag.Int("x", 1, "Number of images")
	outDir := flag.String("o", filepath.Join(os.Getenv("HOME"), "pictures", "generated-wallpapers"), "Output directory")
	setWall := flag.Bool("w", true, "Set wallpaper using termux-wallpaper")
	models := []string{"flux", "stable-diffusion", "anime-v2"}
	flag.Parse()

	if *randomModel {
		rand.Seed(*seed)
		*model = models[rand.Intn(len(models))]
	}

	finalPrompt := *prompt
	if *tag != "" {
		finalPrompt += " " + *tag
	}
	if *style != "" {
		finalPrompt += " " + *style
	}
	if *mood != "" {
		finalPrompt += " " + *mood
	}
	if *negative != "" {
		finalPrompt += " [negative prompt: " + *negative + "]"
	}

	if strings.TrimSpace(*prompt) == "" {
		fmt.Fprintln(os.Stderr, "prompt required (-p)")
		os.Exit(1)
	}
	if *count < 1 {
		fmt.Fprintln(os.Stderr, "count must be > 0")
		os.Exit(1)
	}
	if err := os.MkdirAll(*outDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "failed to create output dir: %v\n", err)
		os.Exit(1)
	}

	for i := 0; i < *count; i++ {
		enc := url.PathEscape(finalPrompt)
		apiURL := fmt.Sprintf("https://image.pollinations.ai/prompt/%s?nologo=true&model=%s", enc, url.QueryEscape(*model))
		if *verbose {
			fmt.Fprintln(os.Stderr, "URL:", apiURL)
		}
		resp, err := http.Get(apiURL)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to fetch image: %v\n", err)
			continue
		}
		if resp.StatusCode != http.StatusOK {
			fmt.Fprintf(os.Stderr, "bad response: %s\n", resp.Status)
			resp.Body.Close()
			continue
		}
		ext := ".jpg"
		if ct := resp.Header.Get("Content-Type"); strings.Contains(ct, "png") {
			ext = ".png"
		}
		fname := fmt.Sprintf("wallai-%d-%d%s", time.Now().Unix(), i+1, ext)
		fpath := filepath.Join(*outDir, fname)
		f, err := os.Create(fpath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to create file: %v\n", err)
			resp.Body.Close()
			continue
		}
		if _, err := io.Copy(f, resp.Body); err != nil {
			fmt.Fprintf(os.Stderr, "failed to save image: %v\n", err)
		}
		f.Close()
		resp.Body.Close()
		fmt.Println("saved", fpath)
		if *setWall {
			if _, err := exec.LookPath("termux-wallpaper"); err == nil {
				_ = exec.Command("termux-wallpaper", "-f", fpath).Run()
			}
		}
	}
}
