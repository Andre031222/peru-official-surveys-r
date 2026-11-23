test_that("ubigeo is padded and split", {
  x <- fa_ubigeo(data.frame(UBIGEO = c(10101, 150101)))
  expect_equal(x$ubigeo, c("010101", "150101"))
  expect_equal(x$department_name, c("Amazonas", "Lima"))
  expect_equal(x$province, c("0101", "1501"))
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

test_that("the district lists match the census and the 2025 register", {
  d17 <- fa_districts(2017)
  expect_equal(nrow(d17), 1874)
  expect_false(anyDuplicated(d17$ubigeo) > 0)
  cpv <- read.csv(system.file("ubigeo", "ubigeo_cpv2017.csv", package = "faperu"),
                  colClasses = "character")
  expect_setequal(d17$ubigeo, cpv$ubigeo)
  expect_equal(nrow(fa_districts(2025)), 1892)
  expect_true("130112" %in% fa_districts(2023)$ubigeo)
  expect_error(fa_districts(1990), class = "faperu_error_input")
})

test_that("every crosswalk row joins a new district to a 2017 district", {
  xw <- read.csv(system.file("ubigeo", "crosswalk_cpv2017.csv", package = "faperu"),
                 colClasses = "character")
  expect_equal(length(unique(xw$ubigeo)), 18)
  expect_true(all(xw$ubigeo_cpv2017 %in% fa_districts(2017)$ubigeo))
  expect_false(any(xw$ubigeo %in% fa_districts(2017)$ubigeo))
  expect_setequal(unique(xw$ubigeo[xw$multi_padre == "si"]), c("090724", "221006"))
})

test_that("new districts go to their 2017 parent, or to NA with two parents", {
  x <- fa_ubigeo(data.frame(ubigeo = c("130112", "090724", "130102", "210101")),
                 year = 2024, base = 2017)
  expect_equal(x$ubigeo_base, c("130102", NA, "130102", "210101"))
  expect_equal(x$ubigeo_status, c("to_parent", "multi_parent", "area_changed", "same"))
})

test_that("aggregating to 2017 keeps the total", {
  df <- data.frame(ubigeo = c("130112", "130102", "180107", "180101"), n = c(5, 7, 2, 3))
  x <- fa_ubigeo(df, year = 2024, base = 2017)
  agg <- tapply(x$n, x$ubigeo_base, sum)
  expect_equal(sum(agg), sum(df$n))
  expect_equal(as.vector(agg[c("130102", "180101")]), c(12, 5))
})

test_that("Putumayo is flagged as partial forward and exact backward", {
  x <- fa_ubigeo(data.frame(ubigeo = c("160109", "160101")), year = 2010, base = 2017)
  expect_equal(x$ubigeo_base, c("160801", "160101"))
  expect_equal(x$ubigeo_status, c("recoded_partial", "same"))
  y <- fa_ubigeo(data.frame(ubigeo = c("160801", "160802")), year = 2017, base = 2010)
  expect_equal(y$ubigeo_base, c("160109", NA))
  expect_equal(y$ubigeo_status, c("recoded", "created_after_base"))
})

test_that("the 2007 Bagua and La Peca swap happens at once", {
  x <- fa_ubigeo(data.frame(ubigeo = c("010201", "010299")), year = 2005, base = 2010)
  expect_equal(x$ubigeo_base, c("010206", "010201"))
  y <- fa_ubigeo(data.frame(ubigeo = c("010206", "010201")), year = 2010, base = 2005)
  expect_equal(y$ubigeo_base, c("010201", "010299"))
})

test_that("the old ENAHO codes are handled", {
  x <- suppressWarnings(fa_ubigeo(data.frame(ubigeo = c("160203", "120699")),
                                  year = 2006, base = 2017))
  expect_equal(x$ubigeo_base, c("160701", NA))
  expect_equal(x$ubigeo_status, c("recoded_partial", "legacy"))
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
