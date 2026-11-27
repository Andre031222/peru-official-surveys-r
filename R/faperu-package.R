#' faperu: Peruvian official surveys and censuses in R
#'
#' One catalog, one download function and a few helpers for ten official
#' sources, and the tools to turn them into official-style figures.
#'
#' Getting the data:
#'
#' - [fa_surveys()], [fa_catalog()]: what there is, without downloading.
#' - [fa_read()], [fa_variables()]: download once, read only the columns
#'   you need.
#' - [fa_design()]: the verified survey design, ready for the survey package.
#' - [fa_ubigeo()]: district codes on the 2017 Census frame.
#'
#' Analysing it:
#'
#' - [fa_estimate()]: means, proportions and totals by domain, with
#'   standard error, confidence interval, coefficient of variation and the
#'   INEI quality band ([fa_quality()]).
#' - [fa_indicator()]: ready indicators checked against INEI's published
#'   figures; [fa_indicators()] lists them.
#' - [fa_link()]: joins estimates from different surveys by department or
#'   district and year.
#' - [fa_map()], [fa_geometry()], [fa_table()]: maps on INEI boundaries and
#'   tables for a paper.
#'
#' Errors have class `faperu_error` plus a specific class such as
#' `faperu_error_download`, so they can be caught with [tryCatch()].
#'
#' @keywords internal
"_PACKAGE"
