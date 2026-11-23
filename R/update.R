.portal <- "https://proyectos.inei.gob.pe/microdatos/"

#' Look for new years
#'
#' Asks the source which years are published and compares them with the
#' catalog. INEI surveys are checked on the INEI microdata portal and the
#' School Census on the ESCALE folder listing. The 2017 Census is not
#' checked: the 2025 Census will be added by hand once its full data are out.
#'
#' A source that cannot be reached does not stop the others; it shows up
#' with `status = "unreachable"`.
#'
#' @param survey One or more short names. `NULL` checks all.
#' @return A data frame with `survey`, `year`, `new` (not in the catalog)
#'   and `status`.
#' @examples
#' \dontrun{
#' fa_check_updates("ena")
#' }
#' @export
fa_check_updates <- function(survey = NULL) {
  ids <- if (is.null(survey)) .ids else vapply(survey, .check_survey, character(1), USE.NAMES = FALSE)
  h <- NULL
  out <- lapply(ids, function(id) {
    x <- .load(id)
    live <- tryCatch(switch(x$fuente,
      inei_portal = {
        if (is.null(h)) h <<- .portal_handle()
        unlist(lapply(x$portal$encuesta, .portal_years, h = h))
      },
      escale_dir = .escale_years(x$listado),
      NULL
    ), error = function(e) e)
    if (inherits(live, "error")) {
      return(data.frame(survey = id, year = NA_integer_, new = NA, status = "unreachable"))
    }
    if (is.null(live)) {
      return(data.frame(survey = id, year = NA_integer_, new = NA, status = "not checked"))
    }
    live <- sort(unique(as.integer(live)))
    data.frame(survey = id, year = live, new = !live %in% fa_years(id), status = "ok")
  })
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

.portal_handle <- function() {
  # The portal keeps the session in a cookie, so the query page has to be opened first.
  h <- curl::new_handle(useragent = "faperu (R package)")
  curl::curl_fetch_memory(paste0(.portal, "Consulta_por_Encuesta.asp?CU=19558"), handle = h)
  h
}

.portal_years <- function(value, h) {
  body <- paste0("bandera=1&_cmbEncuesta=", .js_escape(value))
  curl::handle_setopt(h, post = TRUE, postfields = body)
  curl::handle_setheaders(h, "Content-Type" = "application/x-www-form-urlencoded")
  r <- curl::curl_fetch_memory(paste0(.portal, "CambiaEnc.asp"), handle = h)
  curl::handle_setopt(h, httpget = TRUE)
  html <- iconv(rawToChar(r$content), "WINDOWS-1252", "UTF-8")
  v <- regmatches(html, gregexpr("value=\"?[0-9]{4}", html))[[1]]
  as.integer(sub("value=\"?", "", v))
}

.escale_years <- function(listado) {
  root <- sub("\\{anio\\}/?$", "", listado)
  html <- rawToChar(curl::curl_fetch_memory(root)$content)
  v <- regmatches(html, gregexpr("Educativo/(19|20)[0-9]{2}/", html))[[1]]
  as.integer(gsub("[^0-9]", "", v))
}

# The portal expects the survey name the way JavaScript's escape() would
# write it over Windows-1252 text, not as a normal URL.
.js_escape <- function(x) {
  b <- iconv(x, "UTF-8", "WINDOWS-1252", toRaw = TRUE)[[1]]
  keep <- c(48:57, 65:90, 97:122, utf8ToInt("@*_+-./"))
  paste(vapply(as.integer(b), function(i) {
    if (i %in% keep) intToUtf8(i) else sprintf("%%%02X", i)
  }, character(1)), collapse = "")
}
