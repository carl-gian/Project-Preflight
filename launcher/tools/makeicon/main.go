// makeicon draws the Preflight app icon (original art: a sound-desk fader in
// the Steward "sound, media" duotone, the same drawing as the update screen)
// and writes it as a 256 px PNG. Usage: go run ./tools/makeicon out.png
package main

import (
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
)

type rrect struct {
	x, y, w, h, r float64
	c             color.NRGBA
}

var (
	ember     = color.NRGBA{0x4A, 0x14, 0x10, 0xFF}
	vermilion = color.NRGBA{0xD2, 0x50, 0x2F, 0xFF}
	peach     = color.NRGBA{0xF7, 0xC9, 0xB0, 0xFF}
)

func main() {
	const size, ss = 256, 4 // supersampling for smooth edges
	k := float64(size) / 120.0
	shapes := []rrect{
		{34, 30, 6, 60, 3, vermilion}, {57, 30, 6, 60, 3, vermilion}, {80, 30, 6, 60, 3, vermilion},
		{27, 62, 20, 10, 3, peach}, {50, 40, 20, 10, 3, peach}, {73, 54, 20, 10, 3, peach},
	}
	img := image.NewNRGBA(image.Rect(0, 0, size, size))
	for py := 0; py < size; py++ {
		for px := 0; px < size; px++ {
			var r, g, b, a float64
			for sy := 0; sy < ss; sy++ {
				for sx := 0; sx < ss; sx++ {
					x := (float64(px) + (float64(sx)+0.5)/ss) / k
					y := (float64(py) + (float64(sy)+0.5)/ss) / k
					if math.Hypot(x-60, y-60) > 60 {
						continue
					}
					c := ember
					for _, s := range shapes {
						if inRRect(x, y, s) {
							c = s.c
						}
					}
					r += float64(c.R)
					g += float64(c.G)
					b += float64(c.B)
					a++
				}
			}
			if a > 0 {
				n := float64(ss * ss)
				img.SetNRGBA(px, py, color.NRGBA{uint8(r / a), uint8(g / a), uint8(b / a), uint8(255 * a / n)})
			}
		}
	}
	f, err := os.Create(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer f.Close()
	if err := png.Encode(f, img); err != nil {
		panic(err)
	}
}

func inRRect(x, y float64, s rrect) bool {
	if x < s.x || y < s.y || x > s.x+s.w || y > s.y+s.h {
		return false
	}
	cx := math.Max(s.x+s.r, math.Min(x, s.x+s.w-s.r))
	cy := math.Max(s.y+s.r, math.Min(y, s.y+s.h-s.r))
	return math.Hypot(x-cx, y-cy) <= s.r
}
