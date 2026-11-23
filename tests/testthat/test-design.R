test_that("the design uses the catalog variables", {
  set.seed(1)
  df <- data.frame(FACTOR07 = runif(40, 50, 150), ESTRATO = rep(1:4, each = 10),
                   CONGLOME = rep(1:20, each = 2), y = rbinom(40, 1, 0.3))
  d <- fa_design(df, "enaho")
  expect_s3_class(d, "survey.design2")
  expect_equal(sum(weights(d)), sum(df$FACTOR07))
})

test_that("ENDES weights are scaled and lower-case names work", {
  df <- data.frame(v005 = rep(2e6, 8), v022 = rep(1:2, each = 4), v001 = rep(1:4, each = 2))
  d <- fa_design(df, "endes")
  expect_equal(sum(weights(d)), 16)
})

test_that("strata with one cluster warn unless lonely.psu is set", {
  df <- data.frame(V005 = 1e6, V022 = c(1, 1, 2, 2, 2), V001 = c(1, 1, 2, 3, 3))
  withr::local_options(survey.lonely.psu = NULL)
  expect_warning(fa_design(df, "endes"), class = "faperu_warning_design")
  withr::local_options(survey.lonely.psu = "adjust")
  expect_no_warning(fa_design(df, "endes"))
})

test_that("EPEN crosses department and ESTRATO and drops rows without weight", {
  df <- data.frame(CONGLOMERADO = 1:8, CCDD = rep(c("01", "02"), each = 4),
                   ESTRATO = rep(1:2, 4), FAC300_ANUAL = c(10, NA, 10, 10, 10, 10, 0, 10))
  withr::local_options(survey.lonely.psu = "adjust")
  expect_message(d <- fa_design(df, "epen"), "Dropped 2 rows")
  expect_equal(nrow(d$variables), 6)
  expect_setequal(unique(d$variables$.fa_strata), c("01_1", "01_2", "02_1", "02_2"))
})

test_that("EPE Lima weights are found by pattern", {
  df <- data.frame(conglome = rep(1:4, each = 2), estrato = rep(1:2, each = 4), fa_efm22 = 1:8)
  expect_equal(sum(weights(fa_design(df, "epen"))), 36)
})

test_that("ENAPRES strata are department by area", {
  df <- data.frame(CONGLOMERADO = 1:8, CCDD = rep(c("01", "02"), each = 4),
                   AREA = rep(1:2, 4), ESTRATO = "A", FACTOR = 10)
  d <- fa_design(df, "enapres")
  expect_setequal(unique(d$variables$.fa_strata), c("01_1", "01_2", "02_1", "02_2"))
})

test_that("ENUT and ENARES have no strata and say so", {
  df <- data.frame(CONG = 1:6, CCDD = rep(c("01", "02"), 3), FACTORFINAL = 3)
  expect_warning(d <- fa_design(df, "enut"), class = "faperu_warning_design")
  expect_equal(sum(weights(d)), 18)
  sch <- data.frame(ID_MUESTRA_IE = rep(1:3, each = 2), FACTOR_ALUMNOS = 1:6)
  expect_warning(e <- fa_design(sch, "enares"), class = "faperu_warning_design")
  expect_equal(names(e$cluster), "ID_MUESTRA_IE")
  expect_no_warning(fa_design(df, "enut", strata = "CCDD"))
})

test_that("EEA puts certainty firms in their own stratum", {
  e <- data.frame(IRUC = 1:6, FACTOR_EXP = c(1, 1, 5, 5, 8, 8), y = c(10, 20, 1, 2, 3, 4))
  expect_warning(d <- fa_design(e, "eea"), class = "faperu_warning_design")
  expect_equal(sum(weights(d)), 28)
  only_certain <- subset(d, FACTOR_EXP == 1)
  expect_equal(as.numeric(survey::SE(survey::svytotal(~y, only_certain))), 0)
})

test_that("missing weights and censuses fail clearly", {
  df <- data.frame(x = 1)
  expect_error(fa_design(df, "enapres"), class = "faperu_error_design")
  expect_error(fa_design(df, "cpv2017"), class = "faperu_error_unsupported")
})

# Official 2024 figures from INEI, recomputed from the local copy of the microdata.
test_that("official figures are reproduced", {
  skip_on_cran()
  skip_if_no_local()
  withr::local_options(survey.lonely.psu = "adjust")

  s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.", cache = local_root())
  s$facpob <- s$factor07 * s$mieperho
  p <- survey::svymean(~I(pobreza < 3), fa_design(s, "enaho", weight = "facpob"))
  expect_equal(unname(coef(p)[2]), 0.276, tolerance = 0.001 / 0.276)

  a <- fa_read("ena", 2024, "1911", cache = local_root())
  a <- a[a$p1102 %in% 1 & !is.na(a$estrato) & a$estrato != "", ]
  w <- survey::svymean(~I(p1103 == 2), fa_design(a, "ena"), na.rm = TRUE)
  expect_equal(unname(coef(w)[2]), 0.315, tolerance = 0.001 / 0.315)

  f <- file.path(local_root(), "EPEN", "2024", "935-Modulo76", "EPEN 2024 BD_Publicacion Dpto.csv")
  skip_if_not(file.exists(f), "EPEN 2024 annual file not downloaded")
  e <- utils::read.csv(f, fileEncoding = "latin1")
  d <- suppressMessages(fa_design(e, "epen"))
  u <- survey::svymean(~I(OCUP300 == 2), subset(d, OCUP300 %in% 1:2))
  expect_equal(unname(coef(u)[2]), 0.056, tolerance = 0.001 / 0.056)
  i <- survey::svymean(~I(Informal_P == 1), subset(d, OCUP300 == 1), na.rm = TRUE)
  expect_equal(unname(coef(i)[2]), 0.709, tolerance = 0.001 / 0.709)
})
