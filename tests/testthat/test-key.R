test_that("the ENA key is the same whatever the round calls its identifiers", {
  old <- data.frame(CCDD = "01", CCPP = "01", CCDI = "02", CONGLOMERADO = "7003", NSELUA = "1", UA = "1")
  new <- data.frame(CCDD = "1", CCPP = "1", CCDI = "2", NSEGM = "7003", ID_PROD = "1", UA = "1")
  expect_equal(fa_key(old, "ena"), "010102-7003-1-1")
  expect_equal(fa_key(new, "ena"), fa_key(old, "ena"))
  expect_error(fa_key(new[, -5], "ena"), "ID_PROD or NSELUA")
  expect_error(fa_key(new, "ena", level = "person"), class = "faperu_error_bad_input")
})

test_that("ENAHO keys identify households and people", {
  h <- data.frame(conglome = "015009", vivienda = c("013", "013"), hogar = "11", codperso = c("01", "02"))
  expect_equal(fa_key(h, "enaho"), c("015009-013-11", "015009-013-11"))
  expect_equal(anyDuplicated(fa_key(h, "enaho", level = "person")), 0L)
  expect_error(fa_key(h, "endes"), class = "faperu_error_unsupported")
  expect_error(fa_key(list(), "enaho"), class = "faperu_error_bad_input")
})
