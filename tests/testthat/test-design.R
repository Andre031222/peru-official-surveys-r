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

test_that("the ENDES health questionnaire weight is found, and a missing stratum says where it is", {
  df <- data.frame(peso15_amas = rep(1e6, 8), hv022 = rep(1:2, each = 4), hv001 = rep(1:4, each = 2))
  expect_equal(sum(weights(fa_design(df, "endes"))), 8)
  expect_error(fa_design(df[, "peso15_amas", drop = FALSE], "endes"), "RECH0", class = "faperu_error_design")
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

test_that("a territory keeps the whole sample for the standard errors", {
  set.seed(2)
  df <- data.frame(FACTOR07 = runif(120, 50, 150), ESTRATO = rep(1:6, each = 20),
                   CONGLOME = rep(1:60, each = 2), y = rbinom(120, 1, 0.3),
                   ubigeo = rep(c("210101", "210102", "150101", "080101"), 30))
  full <- fa_design(df, "enaho")
  expect_message(puno <- fa_design(df, "enaho", territory = "Puno"), "whole sample")
  # Same as a domain estimate on the full design, not as filtering first.
  dom <- survey::svyby(~y, ~I(substr(ubigeo, 1, 2) == "21"), full, survey::svymean)
  est <- survey::svymean(~y, puno)
  expect_equal(unname(coef(est)), unname(dom$y[2]))
  expect_equal(as.numeric(survey::SE(est)), unname(dom$se[2]))
  expect_equal(nrow(puno), 60L)
  # Codes of 2, 4 or 6 digits, names without accents, several at once.
  n <- function(t) nrow(suppressMessages(fa_design(df, "enaho", territory = t)))
  expect_equal(n("21"), 60L)
  expect_equal(n("210101"), 30L)
  expect_equal(n(c("15", "8")), 60L)
  expect_equal(n("LIMA"), 30L)
})

test_that("a wrong territory fails clearly", {
  df <- data.frame(FACTOR07 = 1:4, ESTRATO = 1, CONGLOME = 1:4, ubigeo = "210101")
  expect_error(fa_design(df, "enaho", territory = "Narnia"), class = "faperu_error_territory")
  expect_error(fa_design(df, "enaho", territory = "123"), class = "faperu_error_territory")
  expect_error(fa_design(df, "enaho", territory = "15"), class = "faperu_error_territory")
  expect_error(fa_design(df[, 1:3], "enaho", territory = "21"), class = "faperu_error_no_domain")
})

test_that("ENA before 2023 uses DOMINIO and keeps firms in their own strata", {
  withr::local_options(survey.lonely.psu = "adjust")
  df <- data.frame(FACTOR = c(rep(20, 8), 3, 5), CONGLOMERADO = c(1:8, 9, 10),
                   ESTRATO = c(rep("", 8), "1", "2"), DOMINIO = c(rep(1:2, each = 4), 1, 1),
                   CODIGO = c(rep(1, 8), 2, 2))
  expect_warning(expect_message(d <- fa_design(df, "ena"), "separate sampling frame"),
                 class = "faperu_warning_ena_strata")
  expect_setequal(unique(d$variables$.fa_strata), c("dominio_1", "dominio_2", "firms_1", "firms_2"))
  expect_null(d$fpc$popsize)
})

test_that("ENA from 2023 uses ESTRATO and firms surveyed in full add no variance", {
  df <- data.frame(FACTOR_PRODUCTOR = c(rep(30, 8), 1, 1, 1), NSEGM = 1:11,
                   ESTRATO = c(rep(c("a", "b"), each = 4), "", "", ""),
                   CODIGO = c(rep(1, 8), 2, 2, 2), y = c(rep(0, 8), 1, 1, 1))
  d <- suppressMessages(fa_design(df, "ena"))
  expect_equal(sum(d$variables$.fa_strata == "firms"), 3)
  t <- survey::svytotal(~y, d)
  expect_equal(unname(coef(t)), 3)
  expect_equal(unname(as.numeric(survey::SE(t))), 0)
})

test_that("ENA without a usable stratum fails clearly", {
  df <- data.frame(FACTOR = 1:4, CONGLOMERADO = 1:4, ESTRATO = "", CODIGO = 1)
  expect_error(fa_design(df, "ena"), class = "faperu_error_design")
  df2 <- data.frame(FACTOR = 1:4, NSEGM = 1:4, ESTRATO = c("a", "a", "b", ""), CODIGO = 1)
  expect_error(fa_design(df2, "ena"), "1 producers have no stratum")
})
