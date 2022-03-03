set req.http.x-aim-format-list = "png_jpeg_gif";
# default mobile settings
if (req.http.X-UA-Device ~ "pc") {
    set req.http.x-aim-format-list = "webp_png_jpg";
} elsif (req.http.X-UA-Device ~ "smartphone$") {
    set req.http.x-aim-format-list = "png_jpeg_gif";
} elsif (req.http.X-UA-Device ~ "android$") {
    set req.http.x-aim-format-list = "webp_png_jpg";
} elsif (req.http.X-UA-Device ~ "iphone$") {
    set req.http.x-aim-format-list = "png_jpeg_gif";
} elsif (req.http.X-UA-Device ~ "ipad$") {
    set req.http.x-aim-format-list = "png_jpeg_gif";
}
# some specified device settings
