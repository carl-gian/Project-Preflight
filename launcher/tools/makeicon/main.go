// makeicon draws the Preflight artwork (original: a sound-desk fader in the
// Steward "sound, media" duotone on a rounded tile, the same drawing as the
// update screen) and
// writes the files the launcher and the installer need.
//
//	go run ./tools/makeicon -png icon.png                      (launcher icon source)
//	go run ./tools/makeicon -ico x.ico -wizard w.bmp -header h.bmp   (installer art)
package main

import (
	"bytes"
	"encoding/binary"
	"flag"
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
	page      = color.NRGBA{0x12, 0x1A, 0x2B, 0xFF} // Steward dark --page
	white     = color.NRGBA{0xFF, 0xFF, 0xFF, 0xFF}

	shapes = []rrect{
		{34, 30, 6, 60, 3, vermilion}, {57, 30, 6, 60, 3, vermilion}, {80, 30, 6, 60, 3, vermilion},
		{27, 62, 20, 10, 3, peach}, {50, 40, 20, 10, 3, peach}, {73, 54, 20, 10, 3, peach},
	}
	tile = rrect{0, 0, 120, 120, 28, ember}
)

func main() {
	pngOut := flag.String("png", "", "256 px PNG icon")
	icoOut := flag.String("ico", "", "multi-size Windows .ico")
	wizOut := flag.String("wizard", "", "164x314 installer welcome-page bitmap")
	hdrOut := flag.String("header", "", "150x57 installer header bitmap")
	flag.Parse()
	if flag.NArg() == 1 && *pngOut == "" { // old form: makeicon icon.png
		*pngOut = flag.Arg(0)
	}

	if *pngOut != "" {
		var buf bytes.Buffer
		must(png.Encode(&buf, fader(256)))
		must(os.WriteFile(*pngOut, buf.Bytes(), 0o644))
	}
	if *icoOut != "" {
		must(os.WriteFile(*icoOut, ico([]int{16, 24, 32, 48, 64, 128, 256}), 0o644))
	}
	if *wizOut != "" {
		// Dark page with the art circle in the upper third, like a Steward welcome screen.
		bg := solid(164, 314, page)
		paste(bg, fader(124), 20, 60)
		must(os.WriteFile(*wizOut, bmp24(bg), 0o644))
	}
	if *hdrOut != "" {
		bg := solid(150, 57, white)
		paste(bg, fader(45), 150-45-8, 6)
		must(os.WriteFile(*hdrOut, bmp24(bg), 0o644))
	}
}

// fader renders the icon tile at any size, supersampled for smooth edges.
func fader(size int) *image.NRGBA {
	ss := 4
	if size <= 48 {
		ss = 8
	}
	k := float64(size) / 120.0
	img := image.NewNRGBA(image.Rect(0, 0, size, size))
	for py := 0; py < size; py++ {
		for px := 0; px < size; px++ {
			var r, g, b, a float64
			for sy := 0; sy < ss; sy++ {
				for sx := 0; sx < ss; sx++ {
					x := (float64(px) + (float64(sx)+0.5)/float64(ss)) / k
					y := (float64(py) + (float64(sy)+0.5)/float64(ss)) / k
					if !inRRect(x, y, tile) {
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
	return img
}

func inRRect(x, y float64, s rrect) bool {
	if x < s.x || y < s.y || x > s.x+s.w || y > s.y+s.h {
		return false
	}
	cx := math.Max(s.x+s.r, math.Min(x, s.x+s.w-s.r))
	cy := math.Max(s.y+s.r, math.Min(y, s.y+s.h-s.r))
	return math.Hypot(x-cx, y-cy) <= s.r
}

func solid(w, h int, c color.NRGBA) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for i := 0; i < len(img.Pix); i += 4 {
		img.Pix[i], img.Pix[i+1], img.Pix[i+2], img.Pix[i+3] = c.R, c.G, c.B, c.A
	}
	return img
}

// paste alpha-blends src onto dst at (ox, oy).
func paste(dst, src *image.NRGBA, ox, oy int) {
	b := src.Bounds()
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			s := src.NRGBAAt(x, y)
			d := dst.NRGBAAt(ox+x, oy+y)
			a := float64(s.A) / 255
			mix := func(sv, dv uint8) uint8 { return uint8(float64(sv)*a + float64(dv)*(1-a) + 0.5) }
			dst.SetNRGBA(ox+x, oy+y, color.NRGBA{mix(s.R, d.R), mix(s.G, d.G), mix(s.B, d.B), 255})
		}
	}
}

// ico writes classic 32-bit DIB entries (accepted by Windows and by NSIS).
func ico(sizes []int) []byte {
	var images [][]byte
	for _, s := range sizes {
		img := fader(s)
		var d bytes.Buffer
		w32 := func(v any) { must(binary.Write(&d, binary.LittleEndian, v)) }
		w32(uint32(40))
		w32(int32(s))
		w32(int32(s * 2)) // XOR + AND mask
		w32(uint16(1))
		w32(uint16(32))
		w32(uint32(0))
		w32(uint32(0))
		w32([4]int32{})
		for y := s - 1; y >= 0; y-- {
			for x := 0; x < s; x++ {
				c := img.NRGBAAt(x, y)
				d.Write([]byte{c.B, c.G, c.R, c.A})
			}
		}
		maskRow := ((s + 31) / 32) * 4
		d.Write(make([]byte, maskRow*s))
		images = append(images, d.Bytes())
	}
	var out bytes.Buffer
	w := func(v any) { must(binary.Write(&out, binary.LittleEndian, v)) }
	w(uint16(0))
	w(uint16(1))
	w(uint16(len(sizes)))
	offset := 6 + 16*len(sizes)
	for i, s := range sizes {
		dim := uint8(s)
		if s >= 256 {
			dim = 0
		}
		out.Write([]byte{dim, dim, 0, 0})
		w(uint16(1))
		w(uint16(32))
		w(uint32(len(images[i])))
		w(uint32(offset))
		offset += len(images[i])
	}
	for _, im := range images {
		out.Write(im)
	}
	return out.Bytes()
}

func bmp24(img *image.NRGBA) []byte {
	w, h := img.Bounds().Dx(), img.Bounds().Dy()
	row := (w*3 + 3) &^ 3
	var out bytes.Buffer
	wr := func(v any) { must(binary.Write(&out, binary.LittleEndian, v)) }
	out.WriteString("BM")
	wr(uint32(54 + row*h))
	wr(uint32(0))
	wr(uint32(54))
	wr(uint32(40))
	wr(int32(w))
	wr(int32(h))
	wr(uint16(1))
	wr(uint16(24))
	wr(uint32(0))
	wr(uint32(row * h))
	wr([4]int32{2835, 2835, 0, 0})
	pad := make([]byte, row-w*3)
	for y := h - 1; y >= 0; y-- {
		for x := 0; x < w; x++ {
			c := img.NRGBAAt(x, y)
			out.Write([]byte{c.B, c.G, c.R})
		}
		out.Write(pad)
	}
	return out.Bytes()
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
