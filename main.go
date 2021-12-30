package main

import (
	"math"
	"strconv"
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
		resize_mode := r.URL.Query().Get("resize_mode")
		max_width_string := r.URL.Query().Get("resize_resolution")
		max_width, _ := strconv.Atoi(max_width_string)


		resp, err := http.Get("https://" + origin_domain + path)
		if resp.StatusCode != 200 {
			w.WriteHeader(resp.StatusCode)
			byteArray, _ := ioutil.ReadAll(resp.Body)
			w.Write(byteArray)
			return
		}
		if err != nil {
			w.WriteHeader(500)
			w.Write([]byte(err.Error()))
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

		w.Header().Add("X-imtest-mode", resize_mode)
		w.Header().Add("X-imtest-max_width", max_width_string)
		w.Header().Add("X-imtest-convert_width", strconv.Itoa(dst.Bounds().Dx()))
		w.Header().Add("X-imtest-convert_height", strconv.Itoa(dst.Bounds().Dy()))


		// 形式変換
		dst_image_type := src_image_type;
		switch (resize_mode) {
		case "iphone":
			// 変換なし

		// https://developer.android.com/guide/topics/media/media-formats?hl=ja
		case "androidaosp":
			// ~android 5
			// 変換なし

		case "androidchrome":
			// android 6 ~
			dst_image_type = "webp"

		case "pc":
			dst_image_type = "webp"

		default:
			// 変換なし
		}

		switch (dst_image_type) {
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
