vcl 4.0;
import std;
import header;
import dynamic;
include "opts/varnish-devicedetect/devicedetect.vcl";
include "opts/pathlist.vcl";

acl purge {
    "localhost";
    "172.16.0.0"/12;
    "10.0.0.0"/8;
    "192.168.0.0"/16;
    ${PURGEABLE_NETWORK};
}

backend default {
    .host = "${ORIGIN_DOMAIN}";
    .port = "80";
}
probe app_probe {
    .url = "/health";
    .timeout = 1s;
    .window = 8;
    .threshold = 3;
    .interval  = 10s;
}

sub vcl_init {
    new optimizer_director = dynamic.director(
        port = "8080",
        connect_timeout = 0.5s,
        probe = app_probe,
    );
}

sub vcl_recv {
    call devicedetect;

    # strip all query strings
    set req.http.X-Original-Url = req.url;
    set req.url = regsub(req.url, "\?.*$", "");

    if (req.url ~ "\/favicon.ico$") {
        return (synth(1410, "It's gone."));
    }
    if (req.url ~ "\/health$") {
        set req.backend_hint = optimizer_director.backend("app");
        return (pass);
    }

    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(403, "Not allowed."));
        }
        ban("req.http.host == " + req.http.host +
            " && req.url ~ " + req.url);

        return(synth(200, "PURGE accepted"));
    }

    if (req.restarts >= 1) {
        set req.http.x-aim-use = "false";
        set req.http.x-aim-backend-dead = "true";
    } else {
        set req.http.x-aim-use = "true";
        call check_target_path;
        if (req.url !~ "\.(png|jpg|jpeg|gif|webp)$") {
            set req.http.x-aim-use = "false";
        }
        if (req.http.X-Original-Url ~ "NO_IM") {
            set req.http.x-aim-use = "false";
        }
    }


    if (req.http.x-aim-use == "true") {
        set req.http.x-aim-origin-domain = "${ORIGIN_DOMAIN}";
        include "opts/default-device-formatlist.vcl";
        include "opts/default-device-resolutionlist.vcl";
        include "opts/device-formatlist.vcl";
        include "opts/device-resolutionlist.vcl";
        set req.backend_hint = optimizer_director.backend("app");
    } else {
        set req.backend_hint = default;
    }

    if (req.http.x-aim-backend-dead == "true") {
        return (pass);
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
    if (beresp.http.X-aim-errormsg) {
        set beresp.uncacheable = true;
        std.log("backend responded error message. abandon. IP:" + beresp.backend.ip + " url: " + bereq.url );
        set beresp.http.X-aim-abandon = "true";
    }
    unset beresp.http.Vary;
    unset beresp.http.Cache-Control;
    unset beresp.http.Expires;
}
sub vcl_backend_error {
    std.log("backend gone, url: " + bereq.url );
    set beresp.http.X-aim-require-restart = "true";
    set beresp.ttl = 1s;
    set beresp.grace = 0s;
    set beresp.keep = 0s;
    return (deliver);
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
    if (resp.http.X-aim-require-restart) {
        return (restart);
    }

    set resp.http.x-aim-backend-dead = req.http.x-aim-backend-dead;
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
        # workaround to remove header without varnish plus...
        header.regsub(resp, "^(?i)X-aim.+", "X-REMOVE-TARGET: 1");
        unset resp.http.X-REMOVE-TARGET;
    }
}