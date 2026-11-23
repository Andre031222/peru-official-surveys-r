test_that("all ten sources are there", {
  s <- fa_surveys()
  expect_equal(nrow(s), 10)
  expect_setequal(s$survey, c("enaho", "endes", "ena", "epen", "enapres", "enut",
                              "enares", "eea", "escale", "cpv2017"))
})

test_that("years make sense", {
  expect_true(all(c(2004, 2024, 2025) %in% fa_years("enaho")))
  expect_false(2020 %in% fa_years("ena"))
  expect_equal(fa_years("cpv2017"), 2017L)
})

test_that("fa_catalog filters by year and keeps checksums", {
  c24 <- fa_catalog("enaho", 2024)
  expect_true(all(c24$year == 2024))
  expect_true("34" %in% c24$module)
  expect_true(all(nchar(na.omit(c24$sha256)) == 64))
})
