#' Survey design
#'
#' Builds a [survey::svydesign()] object with the weight, strata and cluster
#' variables that the catalog declares for that source. The first declared
#' name found in the data is used, so the same call works for ENDES women
#' (`V005`) and households (`HV005`). Any of them can be overridden, and a
#' stratum can be the crossing of two columns, written `"CCDD*AREA"`.
#'
#' The names were checked in INEI's technical sheets (fichas tecnicas) and in
#' the headers of 2024 and 2025 files; the `diseno` entry of each YAML in
#' `inst/catalog/` lists them with a note and the document behind them.
#'
#' * **EPEN**: `FAC300_ANUAL` (or the quarterly and Lima weights),
#'   `CONGLOMERADO`, and department by `ESTRATO` as strata. Rows without
#'   weight (people under 14) are dropped with a message.
#' * **ENAPRES**: `FACTOR`, `CONGLOMERADO`, department by area. Its
#'   `ESTRATO` column is socioeconomic, not a design stratum.
#' * **ENUT** and **ENARES**: INEI publishes no strata, so there are none
#'   and a warning says so. ENARES weights depend on the questionnaire, and
#'   in the school questionnaires the cluster is the school.
#' * **Annual Economic Survey**: `FACTOR_EXP`, one stage. Firms included
#'   with certainty (`FACTOR_EXP == 1`) form their own stratum with no
#'   variance. The real strata are not published, so standard errors are
#'   approximate.
#'
#' Where a stratum has a single cluster, as in ENDES, `survey` stops unless
#' you set `options(survey.lonely.psu = "adjust")`; faperu warns but does not
#' change the option for you.
#'
#' The ENA has thousands of fine strata, most with one cluster. Collapsing
#' them is not official, but if you need it:
#' `ena$estrato_c <- paste0(ena$CCDD, substr(ena$ESTRATO, 7, 9))` and
#' `fa_design(ena, "ena", strata = "estrato_c")`.
#'
#' @param data A data frame, usually from [fa_read()].
#' @inheritParams fa_years
#' @param weight,strata,cluster Variable names to use instead of the
#'   catalog defaults.
#' @return A `survey.design2` object.
#' @examples
#' \dontrun{
#' s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
#' d <- fa_design(s, "enaho")
#' survey::svymean(~I(pobreza < 3), d)
#' }
#' @export
fa_design <- function(data, survey, weight = NULL, strata = NULL, cluster = NULL) {
  x <- .load(survey)
  if (identical(x$tipo, "censo")) {
    .abort("unsupported", "%s is a census: it has no sampling design.", x$siglas)
  }
  dz <- x$diseno
  certainty <- identical(dz$forzosa, "peso==1") && is.null(strata)
  one_stage <- isTRUE(dz$unietapica) && is.null(cluster)
  w <- .find_var(data, .or(weight, unlist(dz$peso)), "weight", x)
  s <- if (certainty) NULL else .find_var(data, .or(strata, unlist(dz$estrato)), "strata", x, optional = TRUE)
  k <- if (one_stage) NULL else .find_var(data, .or(cluster, unlist(dz$conglomerado)), "cluster", x, optional = TRUE)
  scale <- if (is.null(weight)) as.numeric(.or(dz$escala, 1)) else 1

  data <- as.data.frame(data)
  data$.fa_weight <- as.numeric(data[[w]]) * scale
  if (identical(dz$filtro, "peso>0")) {
    # EPEN only weights people aged 14 and over; the rest are not in the sample.
    keep <- !is.na(data$.fa_weight) & data$.fa_weight > 0
    if (!all(keep)) {
      message(sprintf("Dropped %d rows without `%s` (outside the survey universe).", sum(!keep), w))
      data <- data[keep, , drop = FALSE]
    }
  }
  if (anyNA(data$.fa_weight)) {
    .abort("design", "Weight `%s` is missing in %d rows; filter them first.",
           w, sum(is.na(data$.fa_weight)))
  }

  fpc <- NULL
  if (!is.null(s)) {
    parts <- strsplit(s, "*", fixed = TRUE)[[1]]
    data$.fa_strata <- do.call(paste, c(lapply(parts, function(p) as.character(data[[p]])), sep = "_"))
  } else if (certainty) {
    data$.fa_strata <- ifelse(data$.fa_weight == 1, "certainty", "sampled")
    # Certainty units are the whole population of their stratum: no variance.
    data$.fa_fpc <- stats::ave(data$.fa_weight, data$.fa_strata, FUN = sum)
    fpc <- ~.fa_fpc
    .warn("design", "%s does not publish its strata; standard errors are approximate.", x$siglas)
  }
  has_strata <- !is.null(data$.fa_strata)
  if (has_strata && !is.null(k)) .lonely(data$.fa_strata, data[[k]], x)

  survey::svydesign(
    ids = if (is.null(k)) ~1 else stats::as.formula(paste0("~`", k, "`")),
    strata = if (has_strata) ~.fa_strata else NULL,
    fpc = fpc,
    weights = ~.fa_weight,
    data = data,
    nest = has_strata
  )
}

.lonely <- function(strata, cluster, x) {
  n <- tapply(cluster, strata, function(v) length(unique(v)))
  if (any(n == 1L) && identical(getOption("survey.lonely.psu", "fail"), "fail")) {
    .warn("design", "%d strata of %s have a single cluster; set options(survey.lonely.psu = \"adjust\") before estimating.",
          sum(n == 1L), x$siglas)
  }
}

# A candidate is a column name, two names joined by "*" (a crossed stratum),
# or a regular expression after "re:"; EPE Lima names its weight after each
# rolling quarter.
.find_var <- function(data, candidates, role, x, optional = FALSE) {
  if (length(candidates) == 0L) {
    if (!optional) {
      .abort("design", "The %s variable for %s is not verified yet; pass `%s =` yourself.",
             role, x$siglas, role)
    }
    .warn("design", "INEI does not publish a %s variable for %s; the design has none. Pass `%s =` if you know it.",
          role, x$siglas, role)
    return(NULL)
  }
  low <- tolower(names(data))
  for (cand in candidates) {
    if (startsWith(cand, "re:")) {
      hit <- grep(substring(cand, 4), names(data), ignore.case = TRUE)
      if (length(hit) > 0L) return(names(data)[hit[1]])
      next
    }
    parts <- strsplit(cand, "*", fixed = TRUE)[[1]]
    hit <- match(tolower(parts), low)
    if (!anyNA(hit)) return(paste(names(data)[hit], collapse = "*"))
  }
  .abort("design", "None of the %s variables (%s) is in the data.",
         role, paste(candidates, collapse = ", "))
}
