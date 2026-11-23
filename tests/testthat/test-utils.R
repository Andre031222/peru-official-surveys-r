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
