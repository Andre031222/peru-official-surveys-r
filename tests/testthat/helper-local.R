local_root <- function() {
  Sys.getenv("FAPERU_LOCAL", "/mnt/discoD/Research-Dev/AUP_Papers/datos/inei_microdatos")
}

skip_if_no_local <- function() {
  skip_if_not(dir.exists(local_root()), "Local microdata copy not available")
}

skip_if_offline_tests <- function() {
  skip_on_cran()
  skip_if_not(identical(Sys.getenv("FAPERU_ONLINE"), "1"), "Set FAPERU_ONLINE=1 to test against the sources")
}

# Every download fails as if there were no network, without waiting for retries.
no_network <- function(env = parent.frame()) {
  withr::local_options(faperu.retries = 1L, .local_envir = env)
  local_mocked_bindings(
    .multi = function(urls, dest) {
      data.frame(success = rep(FALSE, length(urls)), status_code = 0, resumefrom = 0,
                 error = "no network in tests", time = 0)
    },
    .env = env
  )
  local_mocked_bindings(curl_download = function(...) stop("no network in tests"),
                        .package = "curl", .env = env)
}
