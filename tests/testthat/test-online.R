# Against the real sources. They only run with FAPERU_ONLINE=1 and download
# about 15 MB into a temporary cache that is removed at the end.

online_cache <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_options(faperu.progress = FALSE, .local_envir = env)
  dir
}

test_that("one small module of each INEI survey downloads, reads by column and weights", {
  skip_if_offline_tests()
  cache <- online_cache()
  cases <- list(
    list("enut", 2024, "1849", c("cong", "factorfinal")),
    list("enares", 2024, "1941", c("conglome", "factor_viv")),
    list("eea", 2024, "2042", c("iruc", "factor_exp")),
    list("enapres", 2010, "101", NULL)
  )
  for (cs in cases) {
    d <- suppressMessages(fa_download(cs[[1]], cs[[2]], cs[[3]], cache = cache))
    expect_equal(d$status, "downloaded", info = cs[[1]])
    expect_equal(fa_download(cs[[1]], cs[[2]], cs[[3]], cache = cache)$status, "cached")
    if (!is.null(cs[[4]])) {
      x <- fa_read(cs[[1]], cs[[2]], cs[[3]], cache = cache, cols = cs[[4]])
      expect_equal(names(x), cs[[4]], info = cs[[1]])
      expect_gt(nrow(x), 100)
    }
  }
})

test_that("a format the portal does not serve falls back to another", {
  skip_if_offline_tests()
  cache <- online_cache()
  d <- suppressMessages(fa_download("epen", 2015, "76", series = "epe_lima",
                                    period = "Ene-Feb-Mar", cache = cache))
  expect_equal(d$format, "SPSS")
})

test_that("a year missing from the catalog is found on the portal", {
  skip_if_offline_tests()
  faperu:::.fa_reset("endes")
  withr::defer(faperu:::.fa_reset("endes"))
  m <- fa_catalog("endes", 2009)
  expect_true(all(c("64", "65") %in% m$module))
})

test_that("an older School Census year is listed and read from DBF", {
  skip_if_offline_tests()
  faperu:::.fa_reset("escale")
  withr::defer(faperu:::.fa_reset("escale"))
  cache <- online_cache()
  x <- suppressMessages(fa_read("escale", 2015, "02 Mat2100.dbf", cache = cache, cols = c("cod_mod", "codgeo")))
  expect_equal(names(x), c("cod_mod", "codgeo"))
  expect_gt(nrow(x), 1000)
})
