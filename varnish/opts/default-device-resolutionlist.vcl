set req.http.x-imtest-resolution = "4096";
# default mobile settings
if (req.http.X-UA-Device ~ "pc") {
    set req.http.x-imtest-resolution = "4096";
} elsif (req.http.X-UA-Device ~ "^mobile") {
    set req.http.x-imtest-resolution = "1280";
} elsif (req.http.X-UA-Device ~ "^tablet") {
    set req.http.x-imtest-resolution = "1980";
}
# some specified device settings
