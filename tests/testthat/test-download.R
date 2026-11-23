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
