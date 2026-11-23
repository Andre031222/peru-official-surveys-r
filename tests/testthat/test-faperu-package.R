test_that("only the fa_ functions are exported", {
  ex <- getNamespaceExports("faperu")
  expect_setequal(ex, c("fa_cache", "fa_catalog", "fa_check_updates", "fa_design",
                        "fa_download", "fa_read", "fa_districts", "fa_surveys", "fa_ubigeo", "fa_years"))
})
