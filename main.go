package main

import (
    "net/http"
	"io/ioutil"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		origin_domain := r.URL.Query().Get("origin_domain")
		path := r.URL.Path
		resize_mode := r.URL.Query().Get("resize_mode")
		max_width := r.URL.Query().Get("resize_resolution")

		resp, _ := http.Get("https://" + origin_domain + path)
		defer resp.Body.Close()
		byteArray, _ := ioutil.ReadAll(resp.Body)

		w.Header().Add("X-imtest-mode", resize_mode)
		w.Header().Add("X-imtest-max_width", max_width)
        w.Write(byteArray)
	})
    http.ListenAndServe(":8080", mux)
}
