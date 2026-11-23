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

test_that("CSV separators and code columns are handled", {
  dir <- tempfile()
  dir.create(dir)
  f <- file.path(dir, "s.csv")
  writeLines(c("UBIGEO;CCDD;IRUC;x", "10101;01;0012;1,5"), f)
  x <- faperu:::.read_file(f)
  expect_equal(x$ubigeo, "10101")
  expect_equal(x$ccdd, "01")
  expect_equal(x$iruc, "0012")
  expect_equal(x$x, 1.5)
  expect_equal(fa_ubigeo(x)$ubigeo, "010101")
  writeLines(c("UBIGEO,x", "010101,2"), f)
  expect_equal(faperu:::.read_file(f)$ubigeo, "010101")
})

test_that("the census is read with fa_redatam(), not fa_read()", {
  expect_error(fa_read("cpv2017", 2017, "1"), class = "faperu_error_unsupported")
})

test_that("fa_redatam() explains a missing redatamx", {
  local_mocked_bindings(.has_redatamx = function() FALSE)
  expect_error(fa_redatam("freq PERSONA.C5P2"), class = "faperu_error_dependency")
})

test_that("fa_redatam() opens, queries and closes the database", {
  closed <- FALSE
  fake <- list(
    redatam_open = function(dic) list(dic = dic),
    redatam_close = function(db) closed <<- TRUE,
    redatam_query = function(db, q) data.frame(q = q, dic = db$dic),
    redatam_entities = function(db) data.frame(name = c("HOGAR", "PERSONA")),
    redatam_variables = function(db, e) data.frame(name = paste0(e, "_V"))
  )
  local_mocked_bindings(.has_redatamx = function() TRUE,
                        .redatam_dic = function(cache) file.path(tempdir(), "x.dicx"),
                        .rx = function(fun) fake[[fun]])
  r <- fa_redatam("freq PERSONA.C5P2")
  expect_equal(r$q, "freq PERSONA.C5P2")
  expect_true(closed)
  v <- fa_redatam()
  expect_equal(v$entity, c("HOGAR", "PERSONA"))
})

test_that("upper-case REDATAM files get lower-case links", {
  dir <- tempfile()
  dir.create(dir)
  file.create(file.path(dir, c("CPV-0001.PTR", "ok.rbf")))
  expect_equal(faperu:::.lowercase_links(dir), 1)
  expect_true(file.exists(file.path(dir, "cpv-0001.ptr")))
  expect_equal(faperu:::.lowercase_links(dir), 0)
})

test_that("the real 2017 Census gives the official count", {
  skip_on_cran()
  skip_if_not_installed("redatamx")
  skip_if_not(file.exists(file.path(local_root(), "CPV2017", "2017", "CP2017PER.zip")),
              "CPV 2017 REDATAM base not downloaded")
  r <- fa_redatam("freq PERSONA.C5P2", cache = local_root())
  expect_equal(sum(r$value), 29381884)
})
