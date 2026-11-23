#' Survey design
#'
#' Builds a [survey::svydesign()] object with the weight, strata and cluster
#' variables that the catalog declares for that source. The first declared
#' name found in the data is used, so the same call works for ENDES women
#' (`V005`) and households (`HV005`). Any of them can be overridden.
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
  w <- .find_var(data, .or(weight, unlist(dz$peso)), "weight", x)
  s <- .find_var(data, .or(strata, unlist(dz$estrato)), "strata", x)
  k <- .find_var(data, .or(cluster, unlist(dz$conglomerado)), "cluster", x)
  scale <- if (is.null(weight)) as.numeric(.or(dz$escala, 1)) else 1

  data <- as.data.frame(data)
  data$.fa_weight <- as.numeric(data[[w]]) * scale
  if (anyNA(data$.fa_weight)) {
    .abort("design", "Weight `%s` has missing values; filter those rows first.", w)
  }
  survey::svydesign(
    ids = stats::as.formula(paste0("~`", k, "`")),
    strata = stats::as.formula(paste0("~`", s, "`")),
    weights = ~.fa_weight,
    data = data,
    nest = TRUE
  )
}

.find_var <- function(data, candidates, role, x) {
  if (length(candidates) == 0L) {
    .abort("design", "The %s variable for %s is not verified yet; pass `%s =` yourself.",
           role, x$siglas, role)
  }
  hit <- match(tolower(candidates), tolower(names(data)))
  hit <- hit[!is.na(hit)]
  if (length(hit) == 0L) {
    .abort("design", "None of the %s variables (%s) is in the data.",
           role, paste(candidates, collapse = ", "))
  }
  names(data)[hit[1]]
}
