test_that("the escape matches JavaScript over Windows-1252", {
  expect_equal(faperu:::.js_escape("EPEN \u2013 CIUDADES"), "EPEN%20%96%20CIUDADES")
  expect_equal(faperu:::.js_escape("ECON\u00d3MICA"), "ECON%D3MICA")
})

test_that("censuses are reported as not checked", {
  u <- fa_check_updates("cpv2017")
  expect_equal(u$status, "not checked")
})

test_that("it reads the years from the INEI portal", {
  skip_on_cran()
  skip_if_not(nzchar(Sys.getenv("FAPERU_ONLINE")), "Set FAPERU_ONLINE=1 to test against the portal")
  u <- fa_check_updates("ena")
  expect_true(2024 %in% u$year)
})

test_that("garbled portal text is repaired and good text is kept", {
  good <- "CARACTERÍSTICAS DEL PRODUCTOR Y SU FAMILIA"
  garbled <- iconv(good, "latin1", "UTF-8")      # UTF-8 bytes read as Latin-1
  expect_equal(faperu:::.unmangle(c(garbled, good, NA)), c(good, good, NA))
  expect_equal(faperu:::.unmangle("Sumarias ( Variables Calculadas )"), "Sumarias ( Variables Calculadas )")
})

test_that("portal pages in UTF-8 or Windows-1252 both come out right", {
  good <- "DÍA ÚLTIMOS PRODUCCIÓN"
  utf8 <- charToRaw(enc2utf8(good))
  cp1252 <- iconv(good, "UTF-8", "WINDOWS-1252", toRaw = TRUE)[[1]]
  expect_equal(faperu:::.portal_text(utf8), good)
  expect_equal(faperu:::.portal_text(cp1252), good)
})
