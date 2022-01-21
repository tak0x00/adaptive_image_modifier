vcl 4.0;
import std;

backend optimizer {
    .host = "app";
    .port = "8080";
}
backend default {
    .host = "${ORIGIN_DOMAIN}";
    .port = "80";
}

sub vcl_recv {
    # strip all query strings
    set req.http.X-Original-Url = req.url;
    set req.url = regsub(req.url, "\?.*$", "");

    if (req.url ~ "\/favicon.ico$") {
        return (synth(1410, "It's gone."));
    }


    if (req.url ~ "\.(png|jpg|jpeg|gif|webp)$" && req.http.X-Original-Url !~ "NO_IM") {
        set req.http.x-imtest-origin-domain = "${ORIGIN_DOMAIN}";
        set req.http.x-imtest-format-list = "webp_png_jpg";
        set req.http.x-imtest-resolution = "4096";
        set req.backend_hint = optimizer;
    } else {
        set req.backend_hint = default;
    }
}

sub vcl_hash {
    hash_data(req.http.X-Original-Url);
    hash_data(req.http.x-imtest-format-list);
    hash_data(req.http.x-imtest-resolution);
    hash_data(req.http.x-imtest-origin-domain);
    return(lookup);
}

sub vcl_backend_fetch {
    if ( bereq.backend == default ) {
        set bereq.http.host = "${ORIGIN_DOMAIN}";
    }
    return (fetch);
}

sub vcl_backend_response {
    unset beresp.http.Vary;
    unset beresp.http.Cache-Control;
    unset beresp.http.Expires;
}

sub vcl_synth {
    if (resp.status == 1404) {
        set resp.status = 404;
        return (deliver);
    }
    if (resp.status == 1410) {
        set resp.status = 410;
        return (deliver);
    }
}