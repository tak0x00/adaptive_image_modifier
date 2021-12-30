package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
	"io/ioutil"
    "net/http"
    "image"
	"image/png"
	"image/gif"
	"image/jpeg"
    "golang.org/x/image/draw"
    "github.com/harukasan/go-libwebp/webp"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		origin_domain := r.URL.Query().Get("origin_domain")
		path := r.URL.Path
		avaliable_format_csv := r.URL.Query().Get("resize_format")
		max_width_string := r.URL.Query().Get("resize_resolution")
		max_width, _ := strconv.Atoi(max_width_string)

		w.Header().Add("X-imtest-request_path", path)
		w.Header().Add("X-imtest-avaliable_format", avaliable_format_csv)
		w.Header().Add("X-imtest-max_width", max_width_string)

		resp, err := http.Get("https://" + origin_domain + path)
		if err != nil {
			w.WriteHeader(500)
			w.Write([]byte(err.Error()))
			return
		}
		if resp.StatusCode != 200 {
			w.WriteHeader(resp.StatusCode)
			byteArray, _ := ioutil.ReadAll(resp.Body)
			w.Write(byteArray)
			return
		}
		defer resp.Body.Close()

		img, src_image_type, err := image.Decode(resp.Body)
		if err != nil {
			w.WriteHeader(500)
			w.Write([]byte(err.Error()))
			return
		}

		var dst *image.RGBA

		// まずリサイズ
		rct := img.Bounds()
		if (rct.Dx() > max_width) {
			dst_width := float64(max_width)
			dst_height := math.Ceil(dst_width / float64(rct.Dx() * rct.Dy()))

			dst = image.NewRGBA(image.Rect(0, 0, int(dst_width), int(dst_height)))
			draw.CatmullRom.Scale(dst, dst.Bounds(), img, img.Bounds(), draw.Over, nil)
		} else {
			dst = image.NewRGBA(image.Rect(0, 0, rct.Dx(), rct.Dy()))
			draw.Copy(dst,image.Point{0,0}, img, img.Bounds(), draw.Over, nil)
		}

		w.Header().Add("X-imtest-convert_width", strconv.Itoa(dst.Bounds().Dx()))
		w.Header().Add("X-imtest-convert_height", strconv.Itoa(dst.Bounds().Dy()))


		avaliable_format := strings.Split(avaliable_format_csv, "_")

		selected_format := src_image_type
		fmt.Println(selected_format)
		// FIXME: issue#4
		if (len(avaliable_format) > 0) {
			selected_format = avaliable_format[0]
		}

		w.Header().Add("X-imtest-convert_format", selected_format)


		// 形式変換
		switch (selected_format) {
		case "jpeg":
			jpeg.Encode(w, dst, &jpeg.Options{Quality: 100})
		case "png":
			png.Encode(w, dst)
		case "gif":
			gif.Encode(w, dst, nil)
		case "webp":
			con, _ := webp.ConfigPreset(webp.PresetDefault, 80)
			err = webp.EncodeRGBA(w, dst, con)
		}
	})
    http.ListenAndServe(":8080", mux)
}
