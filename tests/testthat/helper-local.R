# A local copy of the microdata (<SURVEY>/<year>/<file>.zip). The tests that
# need it run only when FAPERU_LOCAL points to one.
local_root <- function() {
  Sys.getenv("FAPERU_LOCAL", "")
}

skip_if_no_local <- function() {
  skip_if_not(nzchar(local_root()) && dir.exists(local_root()), "Set FAPERU_LOCAL to a local microdata copy")
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

# Writes text files byte by byte, so fixtures in Latin-1 or UTF-8 come out the
# same whatever the locale of the session (a C locale cannot convert them).
write_enc <- function(lines, path, encoding = "UTF-8") {
  txt <- paste0(paste(enc2utf8(lines), collapse = "\n"), "\n")
  writeBin(iconv(txt, "UTF-8", encoding, toRaw = TRUE)[[1]], path)
}
