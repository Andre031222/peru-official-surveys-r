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
#' * **ENDES**: `V005` (women), `HV005` (households), `PESO15_AMAS`
#'   (health questionnaire, people aged 15 and over) or `PESOMEN12`
#'   (children under 12), divided by 1,000,000; strata `HV022` and clusters
#'   `HV001`. The health module (CSALUD01) has neither: merge it with RECH0
#'   by `HHID` first, and the error says so if you forget.
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
#' * **ENA**: the stratum depends on the round. From 2023 it is `ESTRATO`;
#'   from 2014 to 2022 `ESTRATO` is empty for producers (or absent), and
#'   `DOMINIO` is used, with a warning of class `faperu_warning_ena_strata`.
#'   Agricultural firms (`CODIGO` 2) are a separate frame and keep their own
#'   strata; from 2024 they are surveyed in full and add no variance. The
#'   cluster is `CONGLOMERADO` up to 2022 and `NSEGM` from 2023. Read
#'   `ESTRATO`, `DOMINIO` and `CODIGO` with the other columns.
#'
#' The ENA has thousands of fine strata, most with one cluster. Collapsing
#' them is not official, but if you need it:
#' `ena$estrato_c <- paste0(ena$CCDD, substr(ena$ESTRATO, 7, 9))` and
#' `fa_design(ena, "ena", strata = "estrato_c")`.
#'
#' **Territory first, the right way.** To study one department, province or
#' district, pass it as `territory` instead of filtering the rows yourself.
#' Filtering the data before the design drops the strata and clusters of the
#' rest of the country and gives wrong standard errors. With `territory`,
#' faperu builds the design on the whole sample and then keeps only that
#' territory with [survey::subset()][survey::subset.survey.design], so the
#' estimates are those of the territory and their precision is correct.
#'
#' @param data A data frame, usually from [fa_read()].
#' @inheritParams fa_years
#' @param weight,strata,cluster Variable names to use instead of the
#'   catalog defaults.
#' @param territory Optional. Departments, provinces or districts to keep:
#'   INEI codes of 2, 4 or 6 digits (`"21"`, `"2101"`, `"210101"`) or
#'   department names (`"Puno"`, `"Lima"`), several at once if needed. The
#'   data need a `ubigeo` column or `ccdd`, `ccpp` and `ccdi`.
#' @return A `survey.design2` object.
#' @examples
#' \dontrun{
#' s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
#' d <- fa_design(s, "enaho")
#' survey::svymean(~I(pobreza < 3), d)
#'
#' # Only Puno, with correct standard errors
#' puno <- fa_design(s, "enaho", territory = "Puno")
#' survey::svymean(~I(pobreza < 3), puno)
#' }
#' @export
fa_design <- function(data, survey, weight = NULL, strata = NULL, cluster = NULL,
                      territory = NULL) {
  x <- .load(survey)
  if (identical(x$tipo, "censo")) {
    .abort("unsupported", "%s is a census: it has no sampling design.", x$siglas)
  }
  dz <- x$diseno
  certainty <- identical(dz$forzosa, "peso==1") && is.null(strata)
  # The ENA changes its stratum across rounds and mixes two sampling frames
  # (producers and firms); its strata are worked out from the data below.
  ena <- identical(x$id, "ena") && is.null(strata)
  one_stage <- isTRUE(dz$unietapica) && is.null(cluster)
  w <- .find_var(data, .or(weight, unlist(dz$peso)), "weight", x)
  s <- if (certainty || ena) NULL else .find_var(data, .or(strata, unlist(dz$estrato)), "strata", x, optional = TRUE)
  k <- if (one_stage) NULL else .find_var(data, .or(cluster, unlist(dz$conglomerado)), "cluster", x, optional = TRUE)
  scale <- if (is.null(weight)) as.numeric(.or(dz$escala, 1)) else 1

  data <- as.data.frame(data)
  data$.fa_weight <- as.numeric(data[[w]]) * scale
  if (identical(dz$filtro, "peso>0")) {
    # EPEN only weights people aged 14 and over, and the ENA only completed
    # interviews; the other rows are not part of the sample.
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
  if (ena) {
    st <- .ena_strata(data)
    data$.fa_strata <- st$strata
    if (any(st$certain)) {
      # Firms surveyed in full are their whole stratum: no sampling variance.
      data$.fa_fpc <- as.numeric(st$certain)
      fpc <- ~.fa_fpc
    }
  } else if (!is.null(s)) {
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

  inside <- if (!is.null(territory)) .in_territory(data, territory)
  d <- survey::svydesign(
    ids = if (is.null(k)) ~1 else stats::as.formula(paste0("~`", k, "`")),
    strata = if (has_strata) ~.fa_strata else NULL,
    fpc = fpc,
    weights = ~.fa_weight,
    data = data,
    nest = has_strata
  )
  if (is.null(territory)) return(d)
  # The whole sample stays in the design; only the territory is estimated.
  message(sprintf("Territory %s: %d of %d rows; the design keeps the whole sample for the standard errors.",
                  paste(territory, collapse = ", "), sum(inside), nrow(data)))
  # Indexing a survey design keeps every row for the variance (the others get
  # zero weight), exactly as subset() does.
  d[inside, ]
}

# TRUE for the rows inside the territory: INEI codes of 2, 4 or 6 digits,
# or department names.
.in_territory <- function(data, territory) {
  ub <- .ubigeo(data)
  if (is.null(ub)) {
    dd <- .col(data, "ccdd")
    if (is.null(dd)) {
      .abort("no_domain", "To keep a territory the data need a `ubigeo` column or ccdd, ccpp and ccdi.")
    }
    ub <- .pad(data[[dd]], 2)
  }
  plain <- function(x) toupper(iconv(trimws(x), "UTF-8", "ASCII//TRANSLIT"))
  names <- .department_names()
  t <- as.character(territory)
  named <- !grepl("^[0-9]+$", t)
  if (any(named)) {
    code <- names(names)[match(plain(t[named]), plain(names))]
    if (anyNA(code)) {
      .abort("territory", "Unknown department: %s. Use a department name or an INEI code.",
             paste(t[named][is.na(code)], collapse = ", "))
    }
    t[named] <- code
  }
  t <- vapply(t, function(x) if (nchar(x) %% 2 == 1) paste0("0", x) else x, "")
  if (any(!nchar(t) %in% c(2L, 4L, 6L))) {
    .abort("territory", "Territory codes have 2 (department), 4 (province) or 6 (district) digits.")
  }
  if (any(nchar(t) > nchar(ub[1]))) {
    .abort("territory", "The data only identify departments; use 2-digit codes or names.")
  }
  keep <- Reduce(`|`, lapply(t, function(x) startsWith(ub, x)))
  if (!any(keep)) .abort("territory", "No rows in territory %s.", paste(territory, collapse = ", "))
  keep
}

# ENA strata, round by round. Producers (people, CODIGO 1) and agricultural
# firms (CODIGO 2) are two sampling frames, so each keeps its own strata.
# * 2023 onwards: ESTRATO for producers (thousands of fine strata); firms
#   carry no stratum and weight 1, i.e. they are surveyed in full.
# * 2014-2022: ESTRATO is empty for producers (it only classifies firms, and
#   2021-2022 do not have it), so the producers' stratum is DOMINIO.
.ena_strata <- function(data) {
  blank <- function(v) is.na(v) | trimws(as.character(v)) %in% c("", "NA")
  est <- .col(data, "estrato")
  dom <- .col(data, "dominio")
  cod <- .col(data, "codigo")
  firm <- if (is.null(cod)) rep(FALSE, nrow(data)) else .num(data[[cod]]) %in% 2
  people <- !firm
  use_est <- !is.null(est) && any(people) && mean(!blank(data[[est]][people])) > 0.5
  if (use_est) {
    s <- as.character(data[[est]])
  } else if (!is.null(dom)) {
    s <- paste0("dominio_", as.character(data[[dom]]))
    .warn("ena_strata", paste(
      "ENA before 2023: ESTRATO is empty for producers, so DOMINIO is used as their stratum",
      "(the frame INEI used in those rounds)."))
  } else {
    .abort("design", paste(
      "ENA: no stratum for the producers. Read ESTRATO (2023 onwards) or DOMINIO (2014-2022)",
      "with the other columns, or give `strata`."))
  }
  if (any(people & blank(s))) {
    .abort("design", "ENA: %d producers have no stratum; check the module or give `strata`.",
           sum(people & blank(s)))
  }
  certain <- rep(FALSE, nrow(data))
  if (any(firm)) {
    w <- data$.fa_weight[firm]
    if (all(w == 1)) {
      s[firm] <- "firms"
      certain <- firm
    } else {
      fs <- if (is.null(est)) rep("", sum(firm)) else as.character(data[[est]][firm])
      s[firm] <- paste0("firms_", ifelse(blank(fs), "none", fs))
    }
    message(sprintf(paste(
      "ENA: %d agricultural firms (CODIGO 2) are a separate sampling frame and keep their own",
      "strata%s. Drop them first to study producers only."),
      sum(firm), if (any(certain)) ", surveyed in full (no sampling variance)" else ""))
  }
  list(strata = s, certain = certain)
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
  low <- .lower(names(data))
  for (cand in candidates) {
    if (startsWith(cand, "re:")) {
      hit <- grep(substring(cand, 4), names(data), ignore.case = TRUE)
      if (length(hit) > 0L) return(names(data)[hit[1]])
      next
    }
    parts <- strsplit(cand, "*", fixed = TRUE)[[1]]
    hit <- match(.lower(parts), low)
    if (!anyNA(hit)) return(paste(names(data)[hit], collapse = "*"))
  }
  hint <- if (role %in% c("strata", "cluster") && !is.null(x$diseno$pista)) paste0(" ", x$diseno$pista) else ""
  .abort("design", "None of the %s variables (%s) is in the data.%s",
         role, paste(candidates, collapse = ", "), hint)
}
