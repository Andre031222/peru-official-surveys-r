test_that("domains come from ubigeo, ccdd or area", {
  d <- data.frame(ubigeo = c("010101", "150101"), area = c(1, 2))
  expect_equal(faperu:::.domain(d, "department"), c("01", "15"))
  expect_equal(faperu:::.domain(d, "district"), c("010101", "150101"))
  expect_equal(faperu:::.domain(d, "area"), c("urban", "rural"))
  expect_equal(faperu:::.domain(data.frame(CCDD = 7), "department"), "07")
  p <- data.frame(ccdd = "01", ccpp = "02", ccdi = 3)
  expect_equal(faperu:::.domain(p, "district"), "010203")
  expect_error(faperu:::.domain(data.frame(x = 1), "district"), class = "faperu_error_no_domain")
  expect_error(faperu:::.domain(data.frame(x = 1), "area"), class = "faperu_error_no_domain")
})

test_that("a factor domain is named by its levels, not its codes", {
  data <- data.frame(g = factor(c("E", "H", "M", "E")))
  expect_identical(.domain(data, "g"), c("E", "H", "M", "E"))
  lab <- structure(c(1, 2), labels = c(urbano = 1, rural = 2), class = c("haven_labelled", "double"))
  expect_identical(.domain(data.frame(x = 1:2, z = I(lab))[, "z", drop = FALSE], "z"), c("1", "2"))
})
