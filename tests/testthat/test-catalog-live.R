# Years missing from the catalog are looked up at the source. These tests use
# saved pieces of the pages, so they run without a connection.

portal_page <- function(page) {
  switch(page,
    "CambiaEnc.asp" = '<option value="2009">2009</option><option value="2010">2010</option>',
    "CambiaAnio.asp" = '<option value="" selected>&lt;Elija&gt;</option> <option value="5" >Unico </option>',
    "CambiaPeriodo.asp" = paste0(
      '<tr><td>Nro</td></tr><tr> <td>2</td> <td>2009</td> <td>5</td> <td>238</td> ',
      '<td>Encuesta Demogr&aacute;fica - ENDES</td> <td>65</td> <td> <a>Caracteristicas de la Vivienda</a> </td>',
      '<td>x</td><td><a href="/iinei/srienaho/descarga/SPSS/238-Modulo65.zip">s</a></td>',
      '<td><a href="/iinei/srienaho/descarga/DBF/238-Modulo65.zip">d</a></td></tr>')
  )
}

test_that("a year missing from the catalog is read from the INEI portal", {
  faperu:::.fa_reset("endes")
  withr::defer(faperu:::.fa_reset("endes"))
  local_mocked_bindings(.portal_handle = function() "h",
                        .portal_post = function(h, page, body) portal_page(page))
  m <- fa_catalog("endes", 2009)
  expect_equal(m$module, "65")
  expect_equal(m$name, "Caracteristicas de la Vivienda")
  expect_equal(m$formats, "SPSS DBF")
  expect_equal(m$period, "Unico")
  expect_equal(m$series, "endes")
  # Once looked up, it is not asked again in the session.
  local_mocked_bindings(.portal_post = function(...) stop("asked twice"))
  expect_equal(nrow(fa_catalog("endes", 2009)), 1L)
})

test_that("an unreachable portal warns and leaves the catalog as it is", {
  faperu:::.fa_reset("endes")
  withr::defer(faperu:::.fa_reset("endes"))
  local_mocked_bindings(.portal_handle = function() stop("Timeout"))
  expect_warning(m <- fa_catalog("endes", 2008), class = "faperu_warning_unreachable")
  expect_equal(nrow(m), 0L)
  expect_equal(nrow(fa_catalog("endes", 2024)), 13L)
})

test_that("years in the catalog never touch the network", {
  local_mocked_bindings(.portal_handle = function() stop("network"),
                        .escale_files = function(url) stop("network"))
  expect_gt(nrow(fa_catalog("ena", 2024)), 0L)
  expect_gt(nrow(fa_catalog("escale", 2025)), 0L)
})

test_that("an older ESCALE year is listed from its folder", {
  faperu:::.fa_reset("escale")
  withr::defer(faperu:::.fa_reset("escale"))
  local_mocked_bindings(.escale_files = function(url) {
    expect_match(url, "/2015/$")
    c("01 Tabgence.dbf.zip", "02 Mat2100.dbf.zip")
  })
  m <- fa_catalog("escale", 2015)
  expect_equal(m$module, c("01", "02"))
  expect_equal(m$name, c("01 Tabgence.dbf", "02 Mat2100.dbf"))
})
