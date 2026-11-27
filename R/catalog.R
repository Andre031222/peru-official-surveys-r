#' The ten data sources covered by faperu
#'
#' @return A data frame with one row per source, of class `fa_surveys`
#'   (see [faperu-methods]).
#' @examples
#' fa_surveys()
#' @export
fa_surveys <- function() {
  rows <- lapply(.ids, function(id) {
    x <- .load(id)
    a <- unlist(x$anios)
    data.frame(
      survey = id,
      acronym = x$siglas,
      name = x$nombre,
      agency = x$organismo,
      type = x$tipo,
      from = min(a),
      to = max(a),
      years = length(a),
      modules = length(x$modulos),
      design = isTRUE(x$diseno$verificado) && length(x$diseno$peso) > 0L,
      stringsAsFactors = FALSE
    )
  })
  .as(do.call(rbind, rows), "fa_surveys")
}

#' Published years of a source
#'
#' @param survey Short name, for example `"enaho"`. See [fa_surveys()].
#' @return An integer vector.
#' @examples
#' fa_years("ena")
#' @export
fa_years <- function(survey) {
  as.integer(unlist(.load(survey)$anios))
}

#' Modules of a source
#'
#' Lists year, module code, name and available formats. When a copy was
#' already downloaded and verified, it also gives its relative path, size and
#' SHA-256.
#'
#' When you ask for a year that the catalog does not have, faperu looks it up
#' at the source the first time: on the INEI microdata portal for INEI
#' surveys (so a year published after this version, or an old one such as
#' ENDES 2009, still works) and in the ESCALE folder for the School Census,
#' whose catalog only lists the latest year. That needs a connection; the
#' modules found are kept for the session, and their `series` is the last
#' part of the portal survey name.
#'
#' @inheritParams fa_years
#' @param years Years to keep. `NULL` keeps all.
#' @return A data frame with one row per module, of class `fa_catalog`;
#'   `summary()` counts the modules of each year (see [faperu-methods]).
#' @examples
#' head(fa_catalog("enaho", 2024))
#' @export
fa_catalog <- function(survey, years = NULL) {
  x <- .load(survey)
  if (!is.null(years)) x <- .extend(x, years)
  mods <- x$modulos
  if (length(mods) == 0L) {
    return(data.frame())
  }
  pick <- function(f, empty) vapply(mods, function(m) .or(f(m), empty), empty)
  df <- data.frame(
    survey = x$id,
    year = vapply(mods, function(m) as.integer(m$anio), integer(1)),
    series = pick(function(m) m$serie, "main"),
    period = pick(function(m) m$periodo, ""),
    module = pick(function(m) as.character(m$codigo), ""),
    name = pick(function(m) m$nombre, ""),
    formats = pick(function(m) paste(names(m$archivos), collapse = " "), ""),
    path = pick(function(m) m$local$ruta, NA_character_),
    bytes = pick(function(m) as.numeric(m$local$bytes), NA_real_),
    sha256 = pick(function(m) m$local$sha256, NA_character_),
    stringsAsFactors = FALSE
  )
  df$.i <- seq_len(nrow(df))
  if (!is.null(years)) df <- df[df$year %in% years, , drop = FALSE]
  rownames(df) <- NULL
  .as(df, "fa_catalog")
}

# Years missing from the catalog are looked up at the source, once per session.
.extend <- function(x, years) {
  have <- vapply(x$modulos, function(m) as.integer(m$anio), integer(1))
  miss <- setdiff(as.integer(years), c(have, unlist(x$.checked)))
  miss <- miss[!is.na(miss) & miss >= 1990L & miss <= as.integer(format(Sys.Date(), "%Y")) + 1L]
  if (length(miss) == 0L) return(x)
  x <- switch(x$fuente,
    escale_dir = .escale_add(x, miss),
    inei_portal = .portal_add(x, miss),
    x
  )
  x$.checked <- c(unlist(x$.checked), miss)
  .fa[[x$id]] <- x
  x
}

# ESCALE publishes one folder per year. The catalog keeps only the latest; the
# other years are listed from their folder when someone asks for them.
.escale_add <- function(x, years) {
  have <- vapply(x$modulos, function(m) as.integer(m$anio), integer(1))
  for (y in setdiff(intersect(as.integer(years), fa_years(x$id)), have)) {
    files <- tryCatch(.escale_files(sub("{anio}", y, x$listado, fixed = TRUE)),
                      error = function(e) {
                        .warn("unreachable", "Could not list the ESCALE folder for %s: %s",
                              y, conditionMessage(e))
                        character()
                      })
    stems <- sub("\\.zip$", "", files, ignore.case = TRUE)
    x$modulos <- c(x$modulos, lapply(stems, function(f) list(
      anio = y, codigo = sub("^([0-9]+).*$", "\\1", f), nombre = f, archivos = list(ZIP = f)
    )))
  }
  .fa[[x$id]] <- x
  x
}

.escale_files <- function(url) {
  html <- rawToChar(curl::curl_fetch_memory(url)$content)
  Encoding(html) <- "UTF-8"
  v <- regmatches(html, gregexpr(">[^<>]+\\.zip</a>", html, ignore.case = TRUE))[[1]]
  sub("</a>$", "", sub("^>", "", v))
}
