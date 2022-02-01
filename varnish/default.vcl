vcl 4.0;
import std;
include "opts/varnish-devicedetect/devicedetect.vcl";
include "opts/pathlist.vcl";

backend optimizer {
    .host = "app";
    .port = "8080";
}
backend default {
    .host = "${ORIGIN_DOMAIN}";
    .port = "80";
}

sub vcl_recv {
    call devicedetect;

    # strip all query strings
    set req.http.X-Original-Url = req.url;
    set req.url = regsub(req.url, "\?.*$", "");

    if (req.url ~ "\/favicon.ico$") {
        return (synth(1410, "It's gone."));
    }

    set req.http.x-imtest-use = "true";
    call check_target_path;
    if (req.url !~ "\.(png|jpg|jpeg|gif|webp)$") {
        set req.http.x-imtest-use = "false";
    }
    if (req.http.X-Original-Url ~ "NO_IM") {
        set req.http.x-imtest-use = "false";
    }


    if (req.http.x-imtest-use == "true") {
        set req.http.x-imtest-origin-domain = "${ORIGIN_DOMAIN}";
        include "opts/device-formatlist.vcl";
        include "opts/device-resolutionlist.vcl";
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

sub vcl_deliver {
    set resp.http.x-imtest-use = req.http.x-imtest-use;
}