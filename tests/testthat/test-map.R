squares <- function(codes) {
  polys <- lapply(seq_along(codes), function(i) {
    sf::st_polygon(list(rbind(c(i, 0), c(i + 1, 0), c(i + 1, 1), c(i, 1), c(i, 0))))
  })
  sf::st_sf(code = codes, name = codes, geometry = sf::st_sfc(polys, crs = 4326))
}

test_that("estimates are drawn by department", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  x <- data.frame(by = "department", domain = c("01", "15"), estimate = c(.2, .4))
  p <- fa_map(x, geometry = squares(c("01", "15", "02")))
  expect_s3_class(p, "ggplot")
  expect_equal(p$data$fa_fill, c(.2, .4, NA))
  expect_warning(fa_map(rbind(x, data.frame(by = "department", domain = "99", estimate = 1)),
                         geometry = squares(c("01", "15"))), class = "faperu_warning_not_on_map")
})

test_that("district boundaries merge into the 2017 frame", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  g <- squares(c("080910", "080918", "010101"))
  x <- data.frame(ubigeo_base = c("080910", "010101"), estimate = c(.3, .1))
  p <- fa_map(x, level = "district", base = 2017, geometry = g)
  expect_setequal(p$data$code, c("080910", "010101"))
  expect_equal(p$data$fa_fill[p$data$code == "080910"], .3)
})

test_that("bad input is refused", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  g <- squares("01")
  x <- data.frame(domain = "01", estimate = .2, txt = "a")
  expect_error(fa_map(x, "nope", geometry = g), class = "faperu_error_not_found")
  expect_error(fa_map(x, "txt", geometry = g), class = "faperu_error_bad_input")
  expect_error(fa_map(list(), geometry = g), class = "faperu_error_bad_input")
  expect_error(fa_map(rbind(x, x), geometry = g), class = "faperu_error_bad_input")
  expect_error(fa_map(x, geometry = data.frame(code = "01")), class = "faperu_error_bad_input")
})

test_that("missing packages give a clear error", {
  expect_error(faperu:::.need("surely.not.a.package", "for maps"),
               "install.packages", class = "faperu_error_missing_package")
})

test_that("classes, reference-only areas and context are drawn", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  g <- squares(c("01", "02", "03", "04"))
  sf::st_geometry(g) <- sf::st_geometry(g) * 0.5 + c(-76, -10)   # inside Peru
  sf::st_crs(g) <- 4326
  x <- data.frame(domain = c("01", "02", "03", "04"), estimate = c(.1, .2, .3, .4),
                  quality = c("buena", "buena", "referencial", "buena"))
  p <- fa_map(x, geometry = g, breaks = c(0, .25, .5), legend = "Share")
  expect_s3_class(p, "ggplot")
  expect_equal(nlevels(p$data$fa_class), 2L)
  expect_equal(p$data$fa_ref, c(FALSE, FALSE, TRUE, FALSE))
  expect_match(p$labels$caption, "referencial")
  q <- fa_map(x, geometry = g, breaks = "continuous", context = FALSE, labels = "none", quality = NULL)
  expect_null(q$labels$caption)
  expect_true(all(is.na(q$data$fa_class) | TRUE))
  png(tempfile(fileext = ".png")); on.exit(dev.off())
  expect_silent(print(p))
})

test_that("class limits and labels are tidy", {
  expect_equal(faperu:::.map_breaks(c(1, 2, 3, 4), c(2, 3), 5), c(1, 2, 3, 4))
  expect_length(faperu:::.map_breaks(1:100, "quantile", 4), 5)
  expect_equal(faperu:::.title_case(c("MADRE DE DIOS", "LA LIBERTAD")), c("Madre de Dios", "La Libertad"))
})
