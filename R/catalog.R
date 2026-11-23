#' The ten data sources covered by faperu
#'
#' @return A data frame with one row per source.
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
  do.call(rbind, rows)
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
#' @inheritParams fa_years
#' @param years Years to keep. `NULL` keeps all.
#' @return A data frame with one row per module.
#' @examples
#' head(fa_catalog("enaho", 2024))
#' @export
fa_catalog <- function(survey, years = NULL) {
  x <- .load(survey)
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
  df
}
