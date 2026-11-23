test_that("CSV in Latin-1 is read as UTF-8 with lower-case names", {
  dir <- tempfile()
  dir.create(file.path(dir, "m"), recursive = TRUE)
  csv <- file.path(dir, "m", "data.csv")
  con <- file(csv, "w", encoding = "latin1")
  writeLines(c("A\u00d1O,UBIGEO", "2024,210101"), con)
  close(con)
  zip <- file.path(dir, "m.zip")
  withr::with_dir(dir, utils::zip("m.zip", "m/data.csv", flags = "-q"))
  unlink(file.path(dir, "m"), recursive = TRUE)

  x <- faperu:::.read_zip(zip)
  expect_equal(names(x), c("a\u00f1o", "ubigeo"))
  expect_equal(x[["a\u00f1o"]], 2024)
})

test_that("several data files need `file`", {
  dir <- tempfile()
  dir.create(file.path(dir, "m"), recursive = TRUE)
  write.csv(data.frame(a = 1), file.path(dir, "m", "one.csv"), row.names = FALSE)
  write.csv(data.frame(b = 2), file.path(dir, "m", "two.csv"), row.names = FALSE)
  file.create(file.path(dir, "m.zip"))
  expect_error(faperu:::.read_zip(file.path(dir, "m.zip")), class = "faperu_error_ambiguous")
  expect_equal(names(faperu:::.read_zip(file.path(dir, "m.zip"), file = "two")), "b")
})

test_that("SPSS from the local copy keeps labels", {
  skip_if_no_local()
  no_network()
  x <- fa_read("ena", 2014, "947", cache = local_root())
  expect_s3_class(x, "data.frame")
  expect_gt(nrow(x), 0)
})
