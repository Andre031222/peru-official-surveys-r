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
