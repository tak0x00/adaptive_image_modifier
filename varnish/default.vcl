vcl 4.0;
import std;
import header;
include "opts/varnish-devicedetect/devicedetect.vcl";
include "opts/pathlist.vcl";

acl purge {
    "localhost";
    "172.16.0.0"/12;
    "10.0.0.0"/8;
    "192.168.0.0"/16;
    ${PURGEABLE_NETWORK};
}

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

    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(403, "Not allowed."));
        }
        ban("req.http.host == " + req.http.host +
            " && req.url ~ " + req.url);

        return(synth(200, "PURGE accepted"));
    }

    set req.http.x-aim-use = "true";
    call check_target_path;
    if (req.url !~ "\.(png|jpg|jpeg|gif|webp)$") {
        set req.http.x-aim-use = "false";
    }
    if (req.http.X-Original-Url ~ "NO_IM") {
        set req.http.x-aim-use = "false";
    }


    if (req.http.x-aim-use == "true") {
        set req.http.x-aim-origin-domain = "${ORIGIN_DOMAIN}";
        include "opts/default-device-formatlist.vcl";
        include "opts/default-device-resolutionlist.vcl";
        include "opts/device-formatlist.vcl";
        include "opts/device-resolutionlist.vcl";
        set req.backend_hint = optimizer;
    } else {
        set req.backend_hint = default;
    }
}

sub vcl_hash {
    hash_data(req.method);
    hash_data(req.http.X-Original-Url);
    hash_data(req.http.x-aim-format-list);
    hash_data(req.http.x-aim-resolution);
    hash_data(req.http.x-aim-origin-domain);
    return(lookup);
}

sub vcl_backend_fetch {
    if(bereq.http.method == "HEAD") {
        set bereq.method = "GET";
    }
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
    set resp.http.X-aim-use = req.http.x-aim-use;
    set resp.http.X-aim-client-ip = client.ip;
    if (obj.hits > 0) {
        set resp.http.X-aim-cache = "HIT";
        set resp.http.X-aim-cache-hits = obj.hits;
    }
    else {
        set resp.http.X-aim-cache = "MISS";
    }
    if (req.http.X-aim-debug != "true") {
        header.regsub(resp, "^(?i)X-aim.+", "");
    }
}