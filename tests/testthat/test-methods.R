test_that("catalog tables print as a report and stay data frames", {
  x <- fa_catalog("enut", 2024)
  expect_s3_class(x, c("fa_catalog", "data.frame"))
  out <- capture.output(print(x, n = 3))
  expect_match(out[1], "<faperu catalog: ENUT, 7 modules, years 2024>", fixed = TRUE)
  expect_match(out[length(out)], "4 more", fixed = TRUE)
  # Subsetting keeps a usable table; dropping key columns falls back to the plain print.
  expect_s3_class(x[x$module == "1849", ], "fa_catalog")
  expect_no_error(capture.output(print(x[, c("year", "name")])))
  expect_identical(class(as.data.frame(x)), "data.frame")
})

test_that("summary of a catalog counts modules by year", {
  s <- summary(fa_catalog("enut"))
  expect_identical(s$year, c(2024L, 2010L))
  expect_identical(s$modules, c(7L, 6L))
  expect_match(s$formats[s$year == 2024], "STATA")
})

test_that("the list of sources prints one line per source", {
  out <- capture.output(print(fa_surveys()))
  expect_match(out[1], "10 official sources", fixed = TRUE)
  expect_true(any(grepl("^ cpv2017", out)))
})

test_that("download and update tables print a summary", {
  d <- .as(data.frame(survey = "ena", year = 2024L, module = "1893", format = "STATA",
                      path = "/c/ENA/2024/x.zip", status = c("cached", "downloaded"),
                      sha256 = NA, bytes = c(2e6, 3e6), seconds = c(0, 1.5)), "fa_download")
  out <- capture.output(print(d))
  expect_match(out[1], "2 files, 5.0 MB, 1.5 s", fixed = TRUE)
  expect_match(out[2], "1 from the cache, 1 downloaded, 0 changed", fixed = TRUE)

  u <- .as(data.frame(survey = c("ena", "ena", "cpv2017"), year = c(2024L, 2026L, NA),
                      new = c(FALSE, TRUE, NA), status = c("ok", "ok", "not checked")), "fa_updates")
  out <- capture.output(print(u))
  expect_true(any(grepl("ena +2024-2026, 1 new: 2026", out)))
  expect_true(any(grepl("cpv2017 +not checked", out)))
})
