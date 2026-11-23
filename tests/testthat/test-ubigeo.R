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

test_that("the district list grows as INEI creates districts", {
  # 1829 in RENAMU 2004 plus Teniente Manuel Clavero, created by law that year
  expect_equal(nrow(fa_districts(2004)), 1830)
  expect_true("130112" %in% fa_districts(2023)$ubigeo)
  expect_false("130112" %in% fa_districts(2017)$ubigeo)
  expect_error(fa_districts(1990), class = "faperu_error_input")
})

test_that("Putumayo is recoded forward and back", {
  x <- fa_ubigeo(data.frame(ubigeo = c("160109", "160101")), year = 2010, base = 2020)
  expect_equal(x$ubigeo_base, c("160801", "160101"))
  expect_equal(x$ubigeo_status, c("recoded", "same"))
  y <- fa_ubigeo(data.frame(ubigeo = "160801"), year = 2020, base = 2010)
  expect_equal(y$ubigeo_base, "160109")
})

test_that("the 2007 Bagua and La Peca swap happens at once", {
  x <- fa_ubigeo(data.frame(ubigeo = c("010201", "010299")), year = 2005, base = 2010)
  expect_equal(x$ubigeo_base, c("010206", "010201"))
})

test_that("districts created later have no base code and no guessed parent", {
  x <- fa_ubigeo(data.frame(ubigeo = "130112"), year = 2024, base = 2017)
  expect_true(is.na(x$ubigeo_base))
  expect_equal(x$ubigeo_status, "created_after_base")
})

test_that("codes missing from the year's list are flagged", {
  expect_warning(fa_ubigeo(data.frame(ubigeo = "130112"), year = 2017),
                 class = "faperu_warning_ubigeo_year")
  expect_error(fa_ubigeo(data.frame(ubigeo = "130112"), base = 2017), class = "faperu_error_input")
})

test_that("years outside the table use the nearest one", {
  expect_warning(x <- fa_ubigeo(data.frame(ubigeo = "160801"), year = 2026, base = 2017),
                 class = "faperu_warning_ubigeo_year")
  expect_equal(x$ubigeo_base, "160801")
})
