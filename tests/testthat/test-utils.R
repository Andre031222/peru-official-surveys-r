test_that("errors carry a faperu class", {
  e <- tryCatch(faperu:::.check_survey("renipress"), error = function(e) e)
  expect_s3_class(e, "faperu_error_survey")
  expect_s3_class(e, "faperu_error")
  expect_match(conditionMessage(e), "Unknown survey")
})

test_that("fa_cache can be changed for the session", {
  old <- options(faperu.cache = NULL)
  on.exit(options(old))
  d <- tempfile()
  fa_cache(d)
  expect_equal(fa_cache(), normalizePath(d, mustWork = FALSE))
})

test_that("errors and warnings carry their kind", {
  expect_error(faperu:::.abort("x", "a %s", "b"), "a b", class = "faperu_error_x")
  expect_warning(faperu:::.warn("y", "z"), class = "faperu_warning_y")
})

test_that("codes are padded and columns found ignoring case", {
  expect_equal(faperu:::.pad(c(1, 15, NA), 2), c("01", "15", NA))
  expect_equal(faperu:::.col(data.frame(UBIGEO = 1), "ubigeo"), "UBIGEO")
  expect_null(faperu:::.col(data.frame(a = 1), "b"))
})
