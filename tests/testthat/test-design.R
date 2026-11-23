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

test_that("unverified designs and censuses fail clearly", {
  df <- data.frame(x = 1)
  expect_error(fa_design(df, "enapres"), class = "faperu_error_design")
  expect_error(fa_design(df, "cpv2017"), class = "faperu_error_unsupported")
})
