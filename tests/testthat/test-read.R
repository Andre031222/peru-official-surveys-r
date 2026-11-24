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

# One small table written in every format faperu reads.
formats_dir <- function() {
  dir <- tempfile()
  dir.create(dir)
  df <- data.frame(UBIGEO = c("010101", "150101"), FACTOR = c(1.5, 2.25), NOMBRE = c("Ama", "Lima"),
                   stringsAsFactors = FALSE)
  write.csv(df, file.path(dir, "t.csv"), row.names = FALSE)
  writeLines(c("UBIGEO;FACTOR;NOMBRE", "010101;1,5;Ama", "150101;2,25;Lima"), file.path(dir, "s.csv"))
  haven::write_sav(df, file.path(dir, "t.sav"))
  haven::write_dta(df, file.path(dir, "t.dta"))
  foreign::write.dbf(df, file.path(dir, "t.dbf"))
  dir
}

test_that("cols reads only those variables, in any case, in every format", {
  dir <- formats_dir()
  for (f in c("t.csv", "s.csv", "t.sav", "t.dta", "t.dbf")) {
    x <- faperu:::.read_file(file.path(dir, f), cols = c("factor", "UBIGEO"))
    expect_equal(names(x), c("factor", "ubigeo"), info = f)
    expect_equal(as.numeric(x$factor), c(1.5, 2.25), info = f)
    expect_equal(as.character(x$ubigeo), c("010101", "150101"), info = f)
    expect_error(faperu:::.read_file(file.path(dir, f), cols = c("factor", "nope")),
                 "nope", class = "faperu_error_not_found")
  }
})

test_that("both CSV engines give the same table", {
  skip_if_not_installed("data.table")
  dir <- tempfile()
  dir.create(dir)
  f <- file.path(dir, "l.csv")
  con <- file(f, "w", encoding = "latin1")
  writeLines(c("UBIGEO,A\u00d1O,NOMBRE,V", "010101,2024,Ca\u00f1ete,", "150101,2024,,3"), con)
  close(con)
  a <- withr::with_options(list(faperu.csv_engine = "data.table"), faperu:::.read_file(f))
  b <- withr::with_options(list(faperu.csv_engine = "base"), faperu:::.read_file(f))
  expect_equal(a, b)
  expect_equal(a$nombre, c("Ca\u00f1ete", ""))
  expect_equal(names(a)[2], "a\u00f1o")
  s <- withr::with_options(list(faperu.csv_engine = "base"), faperu:::.read_file(f, cols = "nombre"))
  expect_equal(s$nombre, a$nombre)
})

test_that("a byte order mark does not stick to the first name", {
  f <- tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("UBIGEO,x\n010101,1\n")), f)
  expect_equal(faperu:::.read_file(f)$ubigeo, "010101")
})

test_that("a zip with the same table in several formats uses the one asked for", {
  dir <- formats_dir()
  zdir <- tempfile()
  dir.create(file.path(zdir, "m"), recursive = TRUE)
  file.copy(file.path(dir, c("t.csv", "t.sav", "t.dta")), file.path(zdir, "m"))
  withr::with_dir(zdir, utils::zip("m.zip", c("m/t.csv", "m/t.sav", "m/t.dta"), flags = "-q"))
  unlink(file.path(zdir, "m"), recursive = TRUE)
  zip <- file.path(zdir, "m.zip")
  expect_s3_class(faperu:::.read_zip(zip, format = "SPSS"), "tbl_df")
  expect_type(faperu:::.read_zip(zip, format = "STATA")$factor, "double")
  expect_error(faperu:::.read_zip(zip), class = "faperu_error_ambiguous")
})

test_that("only data files are unpacked, Latin-1 names included", {
  skip_on_os("windows")
  skip_if(!nzchar(Sys.which("zip")), "zip not available")
  dir <- tempfile()
  dir.create(dir)
  bad <- rawToChar(as.raw(c(0x50, 0x65, 0x71, 0x75, 0x65, 0xf1, 0x61, 0x73)))  # "Pequeñas" in Latin-1
  ok <- tryCatch({
    writeLines("UBIGEO,x\n010101,1", file.path(dir, paste0(bad, ".csv")))
    writeLines("pdf", file.path(dir, paste0(bad, ".pdf")))
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  skip_if_not(ok, "this file system does not take Latin-1 names")
  system(paste("cd", shQuote(dir), "&& zip -q m.zip *"))
  out <- tempfile()
  expect_equal(faperu:::.zip_formats(file.path(dir, "m.zip")), c("ZIP", "CSV"))
  faperu:::.unzip_data(file.path(dir, "m.zip"), out)
  expect_equal(list.files(out), "Peque\u00f1as.csv")
})

test_that("fa_variables lists names and labels from the header", {
  dir <- formats_dir()
  zdir <- tempfile()
  dir.create(file.path(zdir, "m"), recursive = TRUE)
  df <- data.frame(FACTOR = 1)
  attr(df$FACTOR, "label") <- "Factor de expansion"
  haven::write_sav(df, file.path(zdir, "m", "a.sav"))
  withr::with_dir(zdir, utils::zip("m.zip", "m/a.sav", flags = "-q"))
  local_mocked_bindings(.one_module = function(...) data.frame(path = file.path(zdir, "m.zip"), format = "SPSS"))
  v <- fa_variables("enut", 2024, "1849")
  expect_equal(v$name, "FACTOR")
  expect_equal(v$label, "Factor de expansion")
  expect_equal(v$file, "a.sav")
})

test_that("reading selected columns of the real ENAHO equals the full read", {
  skip_if_no_local()
  no_network()
  a <- fa_read("enaho", 2024, "34", series = "anual", file = "Sumaria-2024\\.", cache = local_root())
  b <- fa_read("enaho", 2024, "34", series = "anual", file = "Sumaria-2024\\.", cache = local_root(),
               cols = c("CONGLOME", "pobreza", "factor07"))
  expect_equal(names(b), c("conglome", "pobreza", "factor07"))
  expect_equal(b$factor07, a$factor07)
  expect_equal(b$pobreza, a$pobreza)
})

test_that("a CSV with line breaks inside answers is repaired", {
  f <- tempfile(fileext = ".csv")
  rows <- c("ID,NOTA,FACTOR", sprintf("%d,ok,1", 1:200), "201,vuelva a las", "3pm,2",
            sprintf("%d,ok,1", 202:300), "301,dos", "", "saltos,3", sprintf("%d,ok,1", 302:400))
  writeLines(rows, f)
  for (eng in c("data.table", "base")) {
    if (eng == "data.table" && !requireNamespace("data.table", quietly = TRUE)) next
    x <- withr::with_options(list(faperu.csv_engine = eng), faperu:::.read_file(f))
    expect_equal(nrow(x), 400L, info = eng)
    expect_equal(x$nota[201], "vuelva a las 3pm", info = eng)
    expect_equal(x$factor[201], 2, info = eng)
    expect_equal(x$nota[301], "dos  saltos", info = eng)
    expect_equal(x$id, 1:400, info = eng)
  }
})

test_that("lines that cannot be repaired are reported", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("A,B", "1,2", "3,4,5", "6,7"), f)
  expect_warning(x <- faperu:::.read_file(f), class = "faperu_warning_csv")
  # The rest of the file is still there.
  expect_equal(nrow(x), 3L)
  expect_equal(x$a, c(1L, 3L, 6L))
})

test_that("UTF-8 CSV files are not converted twice and codes keep their zeros", {
  f <- tempfile(fileext = ".csv")
  con <- file(f, "w", encoding = "UTF-8")
  writeLines(c("CONGLOME,A\u00d1O,PROVINCIA,FACTOR", "07060,2024,FERRE\u00d1AFE,1.5", "12001,2024,JARD\u00cdN,2"), con)
  close(con)
  for (eng in c("data.table", "base")) {
    if (eng == "data.table" && !requireNamespace("data.table", quietly = TRUE)) next
    x <- withr::with_options(list(faperu.csv_engine = eng), faperu:::.read_file(f))
    expect_equal(names(x), c("conglome", "a\u00f1o", "provincia", "factor"), info = eng)
    expect_equal(x$provincia, c("FERRE\u00d1AFE", "JARD\u00cdN"), info = eng)
    expect_equal(x$conglome, c("07060", "12001"), info = eng)
    expect_equal(x$factor, c(1.5, 2), info = eng)
    y <- withr::with_options(list(faperu.csv_engine = eng), faperu:::.read_file(f, cols = c("provincia", "a\u00d1o")))
    expect_equal(names(y), c("provincia", "a\u00f1o"), info = eng)
  }
})

test_that("Stata text that is UTF-8 read as Latin-1 is put back", {
  x <- data.frame(p = c("CA\u00c3\u0091ETE", "CA\u00d1ETE", NA, "LIMA"), stringsAsFactors = FALSE)
  attr(x$p, "label") <- "N\u00c2\u00b0 DE ORDEN"
  y <- faperu:::.unmix(x)
  expect_identical(as.vector(y$p), c("CA\u00d1ETE", "CA\u00d1ETE", NA, "LIMA"))
  expect_identical(attr(y$p, "label"), "N\u00b0 DE ORDEN")
})

test_that("a Stata file haven cannot decode is read again as Latin-1", {
  calls <- character()
  fun <- function(path, ..., encoding = NULL) {
    calls <<- c(calls, if (is.null(encoding)) "default" else encoding)
    if (is.null(encoding)) stop("Unable to convert string to the requested encoding (invalid byte sequence).")
    data.frame(a = 1)
  }
  expect_identical(faperu:::.latin1_retry(fun, "x.dta")$a, 1)
  expect_identical(calls, c("default", "latin1"))
  other <- function(path, ...) stop("file is broken")
  expect_error(faperu:::.latin1_retry(other, "x.dta"), "broken")
})

test_that("an escaped quote inside a CSV field reads as one quote with both engines", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("ID;T01;P01", '001;"CINTA 2"" TRANSP";3', '002;"FILM 18""";4', "003;PAPEL;5"), f)
  for (e in c("data.table", "base")) {
    x <- withr::with_options(list(faperu.csv_engine = e), faperu:::.read_file(f))
    expect_identical(x$t01, c('CINTA 2" TRANSP', 'FILM 18"', "PAPEL"))
  }
})
