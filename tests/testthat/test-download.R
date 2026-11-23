# A fake transfer: copies `src` (or writes `body`) into each destination and
# reports the HTTP code that `code(url)` gives.
fake_multi <- function(src = NULL, body = NULL, code = function(u) 200, calls = NULL) {
  function(urls, dest) {
    if (!is.null(calls)) calls$n <- calls$n + 1L
    st <- vapply(urls, code, numeric(1), USE.NAMES = FALSE)
    for (i in seq_along(urls)) {
      if (st[i] == 0) next
      if (st[i] == 200 && !is.null(src)) file.copy(src, dest[i], overwrite = TRUE)
      else writeLines(.or(body, "<html>error</html>"), dest[i])
    }
    data.frame(success = st != 0, status_code = st, resumefrom = 0,
               error = ifelse(st == 0, "Timeout was reached", NA_character_), time = 0.1)
  }
}

small_zip <- function() {
  dir <- tempfile()
  dir.create(file.path(dir, "m"), recursive = TRUE)
  write.csv(data.frame(UBIGEO = "010101", FACTORFINAL = 1.5, CONG = 1), file.path(dir, "m", "d.csv"),
            row.names = FALSE)
  withr::with_dir(dir, utils::zip("m.zip", "m/d.csv", flags = "-q"))
  file.path(dir, "m.zip")
}


test_that("a cached file with the wrong checksum is not accepted", {
  m <- fa_catalog("ena", 2014)
  m <- m[!is.na(m$path), ][1, ]
  tmp <- tempfile()
  dest <- file.path(tmp, m$path)
  dir.create(dirname(dest), recursive = TRUE)
  writeBin(charToRaw("not the real file"), dest)
  no_network()
  expect_warning(
    expect_error(suppressMessages(fa_download("ena", 2014, m$module, cache = tmp)),
                 class = "faperu_error_download"),
    class = "faperu_warning_checksum"
  )
})

test_that("the local copy is reused without downloading", {
  skip_if_no_local()
  no_network()
  d <- fa_download("ena", 2014, "947", cache = local_root())
  expect_equal(d$status, "cached")
  expect_match(d$path, "505-Modulo947.zip$")
})

test_that("unknown modules and censuses give clear errors", {
  expect_error(fa_download("ena", 2014, "nope"), class = "faperu_error_not_found")
  expect_error(fa_download("cpv2017", 2017), class = "faperu_error_unsupported")
})

test_that("a download enters the cache and the second call reuses it", {
  zip <- small_zip()
  tmp <- tempfile()
  local_mocked_bindings(.multi = fake_multi(src = zip))
  d <- suppressMessages(fa_download("enut", 2024, "1849", cache = tmp))
  expect_equal(d$status, "downloaded")
  expect_equal(d$bytes, file.size(zip))
  expect_false(file.exists(paste0(d$path, ".part")))
  local_mocked_bindings(.multi = function(...) stop("should not download"))
  expect_equal(fa_download("enut", 2024, "1849", cache = tmp)$status, "cached")
  x <- fa_read("enut", 2024, "1849", cache = tmp, cols = c("ubigeo", "factorfinal"))
  expect_equal(names(x), c("ubigeo", "factorfinal"))
  expect_equal(x$ubigeo, "010101")
})

test_that("an error page is never cached", {
  tmp <- tempfile()
  withr::local_options(faperu.retries = 1L)
  local_mocked_bindings(.multi = fake_multi(body = "<html>Service unavailable</html>"))
  expect_error(suppressMessages(fa_download("enut", 2024, "1849", cache = tmp)),
               "did not send a zip", class = "faperu_error_download")
  expect_length(list.files(tmp, recursive = TRUE), 0L)
})

test_that("a broken transfer is retried and resumed", {
  zip <- small_zip()
  tmp <- tempfile()
  calls <- new.env()
  calls$n <- 0L
  first <- TRUE
  local_mocked_bindings(.pause = function(secs) NULL,
                        .multi = fake_multi(src = zip, calls = calls, code = function(u) {
                          if (first) { first <<- FALSE; 0 } else 200
                        }))
  d <- suppressMessages(fa_download("enut", 2024, "1849", cache = tmp))
  expect_equal(d$status, "downloaded")
  expect_equal(calls$n, 2L)
})

test_that("with format auto a missing CSV falls back to another format", {
  zip <- small_zip()
  tmp <- tempfile()
  local_mocked_bindings(.multi = fake_multi(src = zip, code = function(u) if (grepl("/CSV/", u)) 404 else 200))
  d <- suppressMessages(fa_download("enut", 2024, "1849", cache = tmp))
  expect_equal(d$format, "STATA")
  expect_error(suppressMessages(fa_download("enut", 2024, "1849", format = "CSV", cache = tempfile())),
               "HTTP 404", class = "faperu_error_download")
})

test_that("downloads are checked before they are accepted", {
  f <- tempfile()
  writeLines(strrep("<html>error page</html>", 5), f)
  ok <- data.frame(success = TRUE, status_code = 200, resumefrom = 0, error = NA)
  expect_match(faperu:::.bad_download(ok, f), "not send a zip")
  expect_match(faperu:::.bad_download(transform(ok, status_code = 404), f), "HTTP 404")
  expect_match(faperu:::.bad_download(transform(ok, success = FALSE, error = "Timeout"), f), "Timeout")
  zip <- small_zip()
  expect_true(is.na(faperu:::.bad_download(ok, zip)))
  # A server that ignores the range would leave a corrupt file.
  expect_match(faperu:::.bad_download(transform(ok, resumefrom = 10), zip), "does not resume")
  # A cut zip has no central directory.
  cut <- tempfile()
  writeBin(readBin(zip, "raw", file.size(zip) - 30), cut)
  expect_false(faperu:::.is_zip(cut))
})

test_that("modules can be named by their name and file names are encoded", {
  m <- fa_catalog("escale", 2025)
  expect_equal(sum(m$module == "00"), 2L)
  local_mocked_bindings(.multi = function(urls, dest) stop(urls))
  expect_error(fa_download("escale", 2025, "00_Padlocal", cache = tempfile()), "00_Padlocal.zip")
  x <- list(url = "https://x/{anio}/{archivo}")
  expect_equal(faperu:::.url(x, list(anio = 2015), "ZIP", "01 Tabgence.dbf"),
               "https://x/2015/01%20Tabgence.dbf.zip")
})
