test_that("the list of indicators is complete", {
  x <- fa_indicators()
  expect_true(all(c("pobreza_monetaria", "desempleo", "informalidad", "anemia_6_35",
                    "mujeres_productoras") %in% x$id))
  expect_true(all(grepl("https://", x$source)))
  expect_error(fa_indicator("nope", 2024), class = "faperu_error_unknown_indicator")
  expect_error(fa_indicator("desempleo", "2024"), class = "faperu_error_bad_input")
})

# Official INEI figures, rounded to one decimal as published. Only the
# domains INEI published are compared.
check_official <- function(id, by = "national", year = 2024) {
  r <- suppressMessages(fa_indicator(id, year, by = by, cache = local_root()))
  k <- !is.na(r$official)
  expect_true(any(k), label = paste(id, by, year, "has an official figure"))
  expect_equal(round(100 * r$estimate[k], 1), round(100 * r$official[k], 1), label = paste(id, by, year))
  r
}

test_that("ENAHO poverty matches INEI 2024", {
  skip_if_no_local()
  check_official("pobreza_monetaria")
  r <- check_official("pobreza_monetaria", by = "area")
  expect_setequal(r$domain, c("urban", "rural"))
  check_official("pobreza_extrema")
})

test_that("EPEN unemployment and informality match INEI 2024", {
  skip_if_no_local()
  check_official("desempleo")
  check_official("informalidad")
})

test_that("ENDES child anaemia matches INEI 2024 under both criteria", {
  skip_if_no_local()
  check_official("anemia_6_35")
  check_official("anemia_6_35", by = "area")
  check_official("anemia_6_35_rm363")
  check_official("anemia_6_35_rm363", by = "area")
})

test_that("ENA women producers match INEI 2024", {
  skip_if_no_local()
  r <- check_official("mujeres_productoras")
  d <- fa_indicator("mujeres_productoras", 2024, by = "department", cache = local_root())
  expect_gte(nrow(d), 24)
  expect_true(all(is.na(d$official)))
})

test_that("all seven indicators match INEI 2025, the latest year", {
  skip_if_no_local()
  skip_if_not(dir.exists(file.path(local_root(), "ENAHO", "2025")), "No 2025 microdata in the local copy")
  for (id in c("pobreza_monetaria", "pobreza_extrema", "desempleo", "informalidad",
               "anemia_6_35", "anemia_6_35_rm363", "mujeres_productoras")) {
    check_official(id, year = 2025)
  }
  for (id in c("pobreza_monetaria", "pobreza_extrema", "informalidad", "anemia_6_35")) {
    check_official(id, by = "area", year = 2025)
  }
  expect_match(fa_indicator("pobreza_monetaria", 2025, cache = local_root())$source, "1387366")
})
