package main

import (
	"bytes"
	"fmt"
	"image"
	"image/gif"
	"image/png"
	"image/jpeg"
	"io/ioutil"
	"math"
	"net/http"
	"strconv"
	"strings"
	"io"

	"github.com/harukasan/go-libwebp/webp"
	"github.com/kettek/apng"
	libjpeg "github.com/pixiv/go-libjpeg/jpeg"
	"golang.org/x/image/draw"
)

func jpegDecoder(r io.Reader) (image.Image, error) {
    return libjpeg.Decode(r, &libjpeg.DecoderOptions{})
}

func main() {
    image.RegisterFormat("jpeg", "\xff\xd8", jpegDecoder, jpeg.DecodeConfig)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		// LBへ登録するためだけなので何もチェックしない
		w.WriteHeader(200)
		w.Write([]byte("OK"))
		return
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		origin_domain := r.Header.Get("x-aim-origin-domain")
		avaliable_format_csv := r.Header.Get("x-aim-format-list")
		max_width_string := r.Header.Get("x-aim-resolution")
		path := r.URL.Path
		max_width, _ := strconv.Atoi(max_width_string)

		w.Header().Add("X-aim-request_path", path)
		w.Header().Add("X-aim-avaliable_format", avaliable_format_csv)
		w.Header().Add("X-aim-max_width", max_width_string)

		resp, err := http.Get("https://" + origin_domain + path)
		if err != nil {
			fmt.Println("backend error. " + path + " msg: " + err.Error())
			w.WriteHeader(500)
			w.Header().Add("X-aim-errormsg", err.Error())
			w.Write([]byte(err.Error()))
			return
		}
		respBody, _ := ioutil.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != 200 {
			w.WriteHeader(resp.StatusCode)
			w.Write(respBody)
			return
		}

		src_img, src_image_type, err := image.Decode(bytes.NewReader(respBody))
		if err != nil {
			// 読み込みエラったら素通しする
			fmt.Println("file read error. " + path + " msg: " + err.Error())
			w.Header().Add("X-aim-errormsg", err.Error())
			w.Write(respBody)
			return
		}
		// agif/apngは処理しない issue#2
		if src_image_type == "gif" {
			tmpimg, _ := gif.DecodeAll(bytes.NewReader(respBody))
			if len(tmpimg.Image) > 1 {
				fmt.Println("agif detected. " + path)
				w.WriteHeader(resp.StatusCode)
				w.Write(respBody)
				return
			}
		}
		if src_image_type == "png" {
			tmpimg, _ := apng.DecodeAll(bytes.NewReader(respBody))
			if len(tmpimg.Frames) > 1 {
				fmt.Println("apng detected. " + path)
				w.WriteHeader(resp.StatusCode)
				w.Write(respBody)
				return
			}
		}

		var resizedImage *image.RGBA

		// まずリサイズ
		rct := src_img.Bounds()
		if rct.Dx() > max_width {
			dst_width := float64(max_width)
			dst_height := math.Ceil(dst_width / float64(rct.Dx()*rct.Dy()))

			resizedImage = image.NewRGBA(image.Rect(0, 0, int(dst_width), int(dst_height)))
			draw.CatmullRom.Scale(resizedImage, resizedImage.Bounds(), src_img, src_img.Bounds(), draw.Over, nil)
		} else {
			resizedImage = image.NewRGBA(image.Rect(0, 0, rct.Dx(), rct.Dy()))
			draw.Copy(resizedImage, image.Point{0, 0}, src_img, src_img.Bounds(), draw.Over, nil)
		}
		// 気休め。
		src_img = nil

		w.Header().Add("X-aim-convert_width", strconv.Itoa(resizedImage.Bounds().Dx()))
		w.Header().Add("X-aim-convert_height", strconv.Itoa(resizedImage.Bounds().Dy()))

		avaliable_format := strings.Split(avaliable_format_csv, "_")

		selected_format := src_image_type
		// FIXME: issue#4
		if len(avaliable_format) > 0 {
			selected_format = avaliable_format[0]
		}

		w.Header().Add("X-aim-convert_format", selected_format)

		// 形式変換
		outputImageBuffer := new(bytes.Buffer)
		switch selected_format {
		case "jpeg":
			w.Header().Add("Content-Type", "image/jpeg")
			libjpeg.Encode(outputImageBuffer, resizedImage, &libjpeg.EncoderOptions{Quality: 100})
		case "png":
			w.Header().Add("Content-Type", "image/png")
			png.Encode(outputImageBuffer, resizedImage)
		case "gif":
			w.Header().Add("Content-Type", "image/gif")
			gif.Encode(outputImageBuffer, resizedImage, nil)
		case "webp":
			w.Header().Add("Content-Type", "image/webp")
			con, _ := webp.ConfigPreset(webp.PresetDefault, 80)
			err = webp.EncodeRGBA(outputImageBuffer, resizedImage, con)
		}

		w.Header().Add("Content-Length", strconv.Itoa(outputImageBuffer.Len()))
		w.Write(outputImageBuffer.Bytes())
		w.(http.Flusher).Flush()
	})
	http.ListenAndServe(":8080", mux)
}
