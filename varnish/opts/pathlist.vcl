sub check_target_path {
    if (req.url ~ "/where/you/wont/apply/conversion/*") { set req.http.x-imtest-use = "false"; }
}
