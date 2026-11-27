#' Keys to join the modules of one survey round
#'
#' Builds one text key per row, the same in every round even where INEI
#' renamed the identifiers, so that modules of the same round can be joined
#' with [merge()].
#'
#' * **ENA** (`level = "unit"`): district, cluster, producer and
#'   agricultural unit. The cluster is `CONGLOMERADO` up to 2022 and `NSEGM`
#'   from 2023; the producer is `NSELUA` up to 2022 and `ID_PROD` from 2023.
#'   With this key, chapters such as 400B and 500AB join in full in every
#'   round from 2014 to 2025.
#' * **ENAHO**: the household (`CONGLOME`, `VIVIENDA`, `HOGAR`), or the
#'   person with `level = "person"` (adds `CODPERSO`).
#'
#' Keys identify units within one round only. The ENA is a repeated cross
#' section, not a panel: the same key in two years is not the same farm.
#' Compare rounds by area with [fa_link()].
#'
#' @param data A data frame from [fa_read()] with the identifier columns.
#' @inheritParams fa_years
#' @param level `"unit"` (ENA agricultural unit, ENAHO household) or
#'   `"person"` (ENAHO only).
#' @return A character vector with one key per row.
#' @export
#' @examples
#' ena <- data.frame(CCDD = "01", CCPP = "01", CCDI = "02", NSEGM = "7003",
#'                   ID_PROD = "1", UA = "1")
#' fa_key(ena, "ena")
#' hog <- data.frame(conglome = "015009", vivienda = "013", hogar = "11", codperso = "01")
#' fa_key(hog, "enaho", level = "person")
fa_key <- function(data, survey, level = c("unit", "person")) {
  if (!is.data.frame(data)) .abort("bad_input", "`data` must be a data frame.")
  level <- match.arg(level)
  survey <- tolower(survey)
  need <- function(names, what) {
    col <- .col(data, names)
    if (is.null(col)) {
      .abort("not_found", "No %s column: read one of %s with the data.", what,
             paste(toupper(names), collapse = " or "))
    }
    trimws(as.character(unclass(data[[col]])))
  }
  if (survey == "ena") {
    if (level == "person") .abort("bad_input", "The ENA has no person key; use level = \"unit\".")
    ub <- .ubigeo(data)
    if (is.null(ub)) .abort("not_found", "No district code: read UBIGEO or CCDD, CCPP and CCDI.")
    parts <- list(ub, need(c("nsegm", "conglomerado"), "cluster"),
                  need(c("id_prod", "nselua"), "producer"), need("ua", "agricultural unit"))
  } else if (survey == "enaho") {
    parts <- list(need("conglome", "cluster"), need("vivienda", "dwelling"), need("hogar", "household"))
    if (level == "person") parts <- c(parts, list(need("codperso", "person")))
  } else {
    .abort("unsupported", "fa_key() knows the ENA and the ENAHO keys, not those of `%s`.", survey)
  }
  do.call(paste, c(parts, sep = "-"))
}
