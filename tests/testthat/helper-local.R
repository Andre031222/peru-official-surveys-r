local_root <- function() {
  Sys.getenv("FAPERU_LOCAL", "/mnt/discoD/Research-Dev/AUP_Papers/datos/inei_microdatos")
}

skip_if_no_local <- function() {
  skip_if_not(dir.exists(local_root()), "Local microdata copy not available")
}

no_network <- function(env = parent.frame()) {
  local_mocked_bindings(curl_download = function(...) stop("no network in tests"),
                        .package = "curl", .env = env)
}
