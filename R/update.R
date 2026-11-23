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

.portal_post <- function(h, page, body) {
  curl::handle_setopt(h, post = TRUE, postfields = body, timeout = 60)
  curl::handle_setheaders(h, "Content-Type" = "application/x-www-form-urlencoded")
  on.exit(curl::handle_setopt(h, httpget = TRUE), add = TRUE)
  r <- curl::curl_fetch_memory(paste0(.portal, page), handle = h)
  if (r$status_code != 200) stop(sprintf("HTTP %s from %s", r$status_code, page), call. = FALSE)
  iconv(rawToChar(r$content), "WINDOWS-1252", "UTF-8")
}

.portal_years <- function(value, h) {
  html <- .portal_post(h, "CambiaEnc.asp", paste0("bandera=1&_cmbEncuesta=", .js_escape(value)))
  v <- regmatches(html, gregexpr("value=\"?[0-9]{4}", html))[[1]]
  as.integer(sub("value=\"?", "", v))
}

# Add to the catalog the modules the portal lists for years it does not have.
.portal_add <- function(x, years) {
  h <- tryCatch(.portal_handle(), error = function(e) e)
  if (inherits(h, "error")) {
    .warn("unreachable", "The INEI portal did not answer (%s); only the catalog is used.",
          conditionMessage(h))
    return(x)
  }
  for (enc in unlist(x$portal$encuesta)) {
    live <- tryCatch(.portal_years(enc, h), error = function(e) integer())
    for (y in intersect(years, live)) {
      mods <- tryCatch(.portal_modules(enc, y, h), error = function(e) {
        .warn("unreachable", "Could not list %s %s on the INEI portal: %s", enc, y, conditionMessage(e))
        list()
      })
      x$modulos <- c(x$modulos, mods)
    }
  }
  x
}

# The portal asks for the survey, then the year, then the period, and only
# then shows the table of modules with one link per format.
.portal_modules <- function(enc, year, h) {
  base <- paste0("bandera=1&_cmbEncuesta=", .js_escape(enc), "&_cmbAnno=", year)
  html <- .portal_post(h, "CambiaAnio.asp", base)
  opt <- regmatches(html, gregexpr("<option value=\"([^\"]+)\"[^>]*>([^<]*)", html))[[1]]
  per <- sub("^<option value=\"([^\"]+)\".*$", "\\1", opt)
  lab <- trimws(.unhtml(sub("^.*>", "", opt)))
  serie <- tolower(trimws(sub("^.*[-\u2013] *", "", enc)))
  out <- list()
  for (k in seq_along(per)) {
    tab <- .portal_post(h, "CambiaPeriodo.asp", paste0(base, "&_cmbTrimestre=", .js_escape(per[k])))
    rows <- regmatches(tab, gregexpr("(?s)<tr[^>]*>.*?</tr>", tab, perl = TRUE))[[1]]
    for (r in rows) {
      td <- regmatches(r, gregexpr("(?s)<td[^>]*>.*?</td>", r, perl = TRUE))[[1]]
      td <- trimws(gsub("\\s+", " ", .unhtml(gsub("<[^>]+>", " ", td))))
      if (length(td) < 7L || !grepl("^[0-9]+$", td[1])) next
      links <- regmatches(r, gregexpr("descarga/(CSV|STATA|SPSS|DBF)/[^\"/]+\\.zip", r))[[1]]
      if (length(links) == 0L) next
      fmt <- sub("^descarga/([A-Z]+)/.*$", "\\1", links)
      stem <- sub("\\.zip$", "", basename(links))
      out[[length(out) + 1L]] <- list(
        anio = year, periodo = lab[k], serie = serie, encuesta_inei = td[4],
        codigo = td[6], nombre = td[7], archivos = as.list(stats::setNames(stem, fmt))
      )
    }
  }
  out
}

.unhtml <- function(x) {
  ent <- c("&aacute;" = "\u00e1", "&eacute;" = "\u00e9", "&iacute;" = "\u00ed", "&oacute;" = "\u00f3",
           "&uacute;" = "\u00fa", "&ntilde;" = "\u00f1", "&Aacute;" = "\u00c1", "&Eacute;" = "\u00c9",
           "&Iacute;" = "\u00cd", "&Oacute;" = "\u00d3", "&Uacute;" = "\u00da", "&Ntilde;" = "\u00d1",
           "&iacute" = "\u00ed", "&nbsp;" = " ", "&lt;" = "<", "&gt;" = ">", "&amp;" = "&")
  for (e in names(ent)) x <- gsub(e, ent[[e]], x, fixed = TRUE)
  x
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
