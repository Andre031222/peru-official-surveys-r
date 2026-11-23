test_that("ubigeo is padded and split", {
  x <- fa_ubigeo(data.frame(UBIGEO = c(210101, 150101)))
  expect_equal(x$ubigeo, c("210101", "150101"))
  expect_equal(x$department_name, c("Puno", "Lima"))
  expect_equal(x$province, c("2101", "1501"))
})

test_that("it builds the code from CCDD, CCPP and CCDI", {
  x <- fa_ubigeo(data.frame(CCDD = 21, CCPP = 1, CCDI = 1))
  expect_equal(x$ubigeo, "210101")
})

test_that("invalid codes become NA with a warning", {
  expect_warning(x <- fa_ubigeo(data.frame(ubigeo = c("990101", "210101"))),
                 class = "faperu_warning_ubigeo")
  expect_true(is.na(x$ubigeo[1]))
})
