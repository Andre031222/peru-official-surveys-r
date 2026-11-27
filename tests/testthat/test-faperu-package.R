test_that("only the fa_ functions are exported", {
  ex <- getNamespaceExports("faperu")
  # Getting the data.
  data <- c("fa_cache", "fa_catalog", "fa_check_updates", "fa_design", "fa_download", "fa_read",
            "fa_redatam", "fa_districts", "fa_surveys", "fa_ubigeo", "fa_variables", "fa_years")
  # Analysing it.
  analysis <- c("fa_estimate", "fa_quality", "fa_indicator", "fa_indicators", "fa_link",
                "fa_geometry", "fa_map", "fa_table")
  expect_setequal(ex, c(data, analysis))
})
