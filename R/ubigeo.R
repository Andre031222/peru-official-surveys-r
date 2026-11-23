.departments <- c(
  "01" = "Amazonas", "02" = "\u00c1ncash", "03" = "Apur\u00edmac", "04" = "Arequipa",
  "05" = "Ayacucho", "06" = "Cajamarca", "07" = "Callao", "08" = "Cusco",
  "09" = "Huancavelica", "10" = "Hu\u00e1nuco", "11" = "Ica", "12" = "Jun\u00edn",
  "13" = "La Libertad", "14" = "Lambayeque", "15" = "Lima", "16" = "Loreto",
  "17" = "Madre de Dios", "18" = "Moquegua", "19" = "Pasco", "20" = "Piura",
  "21" = "Puno", "22" = "San Mart\u00edn", "23" = "Tacna", "24" = "Tumbes",
  "25" = "Ucayali"
)

.ubigeo_years <- c(2004L, 2025L)

.ubigeo_tables <- function() {
  if (is.null(.fa$districts)) {
    read <- function(f) {
      utils::read.csv(system.file("ubigeo", f, package = "faperu", mustWork = TRUE),
                      colClasses = "character", encoding = "UTF-8", na.strings = "")
    }
    d <- read("ubigeo_distritos.csv")
    d$desde <- as.integer(d$desde)
    d$hasta <- as.integer(d$hasta)
    ch <- read("ubigeo_cambios.csv")
    ch$anio <- as.integer(ch$anio)
    .fa$districts <- d
    .fa$changes <- ch
  }
  list(districts = .fa$districts, changes = .fa$changes)
}

.check_year <- function(year, arg, clamp = FALSE) {
  if (length(year) != 1L || is.na(suppressWarnings(as.integer(year)))) {
    .abort("input", "`%s` must be a single year.", arg)
  }
  year <- as.integer(year)
  r <- .ubigeo_years
  if (year >= r[1] && year <= r[2]) return(year)
  if (!clamp) {
    .abort("input", "`%s` = %d is outside the ubigeo table (%d-%d).", arg, year, r[1], r[2])
  }
  # Data from before 2004 or after the last RENAMU still need a coding; the
  # nearest year is the best we have, but changes outside the range are unknown.
  near <- if (year < r[1]) r[1] else r[2]
  .warn("ubigeo_year", "`%s` = %d is outside the ubigeo table (%d-%d); using %d.",
        arg, year, r[1], r[2], near)
  near
}

#' Districts valid in a year
#'
#' The official INEI district list for one year, built from the National
#' Registry of Municipalities (RENAMU) 2004-2025. For districts created by
#' law before they first appear in RENAMU, the start year is the year of the
#' law, taken from INEI's 2025 national directory. See
#' `system.file("ubigeo", package = "faperu")` and the package README for
#' sources.
#'
#' @param year A year between 2004 and 2025.
#' @return A data frame with `ubigeo`, `distrito`, `provincia`,
#'   `departamento`, `desde`, `hasta`, the creation law and the year the
#'   district first appears in RENAMU.
#' @examples
#' nrow(fa_districts(2017))
#' @export
fa_districts <- function(year) {
  year <- .check_year(year, "year")
  d <- .ubigeo_tables()$districts
  keep <- d$desde <= year & (is.na(d$hasta) | d$hasta >= year)
  out <- d[keep, , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Standard and harmonised ubigeo columns
#'
#' Adds a six-digit `ubigeo` with its `department`, `province` and
#' `department_name`. It takes an existing ubigeo column, or builds one from
#' INEI's separate codes (`CCDD`, `CCPP`, `CCDI`), as in the ENA.
#'
#' With `year` and `base`, it also translates the codes from the coding used
#' in `year` to the coding used in `base`, following the recodings that INEI
#' made when new provinces were created (Datem del Maranon in 2006, Putumayo
#' in 2015) and the Bagua and La Peca swap of 2007. Districts created between
#' the two years have no code in the older coding: their `ubigeo_base` is
#' `NA` and `ubigeo_status` says why. No parent district is guessed.
#'
#' @param data A data frame.
#' @param var Name of the ubigeo column. If `NULL`, it looks for `ubigeo`
#'   and then for `ccdd`, `ccpp` and `ccdi` (any case).
#' @param year Year the data were collected. Needed for `base`, and used to
#'   flag codes that did not exist that year. Years outside 2004-2025 are
#'   moved to the nearest end of the table, with a warning.
#' @param base Year whose coding you want, for example `2017` to match the
#'   2017 Census.
#' @return `data` with the new columns. With `base`, also `ubigeo_base` and
#'   `ubigeo_status` (`"same"`, `"recoded"`, `"created_after_base"`,
#'   `"not_in_base"` or `"unknown"`).
#' @examples
#' fa_ubigeo(data.frame(UBIGEO = c("210101", "150101")))
#' fa_ubigeo(data.frame(CCDD = "21", CCPP = "01", CCDI = "01"))
#' fa_ubigeo(data.frame(ubigeo = c("160109", "160101")), year = 2010, base = 2020)
#' @export
fa_ubigeo <- function(data, var = NULL, year = NULL, base = NULL) {
  low <- tolower(names(data))
  col <- function(n) data[[match(n, low)]]
  if (!is.null(var)) {
    if (!var %in% names(data)) .abort("input", "Column `%s` is not in the data.", var)
    u <- data[[var]]
  } else if ("ubigeo" %in% low) {
    u <- col("ubigeo")
  } else if (all(c("ccdd", "ccpp", "ccdi") %in% low)) {
    u <- paste0(.pad(col("ccdd"), 2), .pad(col("ccpp"), 2), .pad(col("ccdi"), 2))
  } else {
    .abort("input", "No ubigeo column and no CCDD/CCPP/CCDI columns; set `var`.")
  }
  u <- .pad(u, 6)
  bad <- !grepl("^[0-9]{6}$", u) | !substr(u, 1, 2) %in% names(.departments)
  if (any(bad & !is.na(u))) {
    .warn("ubigeo", "%d values are not valid six-digit ubigeos; set to NA.", sum(bad & !is.na(u)))
  }
  u[bad] <- NA_character_
  data$ubigeo <- u
  data$department <- substr(u, 1, 2)
  data$province <- substr(u, 1, 4)
  data$department_name <- unname(.departments[data$department])

  if (!is.null(base) && is.null(year)) {
    .abort("input", "`base` needs `year`: the year whose coding the data use.")
  }
  if (!is.null(year)) {
    year <- .check_year(year, "year", clamp = TRUE)
    known <- !is.na(u) & u %in% fa_districts(year)$ubigeo
    n_out <- length(unique(u[!is.na(u) & !known]))
    if (n_out > 0L) {
      .warn("ubigeo_year", "%d distinct codes are not in the INEI district list for %d.", n_out, year)
    }
  }
  if (!is.null(base)) {
    base <- .check_year(base, "base", clamp = TRUE)
    h <- .harmonise(u, year, base)
    data$ubigeo_base <- h$code
    data$ubigeo_status <- h$status
  }
  data
}

.harmonise <- function(u, year, base) {
  ch <- .ubigeo_tables()$changes
  code <- u
  steps <- if (base > year) seq_len(base - year) + year else if (base < year) rev(seq(base + 1L, year)) else integer(0)
  for (y in steps) {
    step <- ch[ch$anio == y, , drop = FALSE]
    if (nrow(step) == 0L) next
    # All changes of one year happen at once: in 2007 Bagua took La Peca's old code.
    from <- if (base > year) step$de else step$a
    to <- if (base > year) step$a else step$de
    hit <- match(code, from)
    code[!is.na(hit)] <- to[hit[!is.na(hit)]]
  }
  in_base <- !is.na(code) & code %in% fa_districts(base)$ubigeo
  in_year <- !is.na(u) & u %in% fa_districts(year)$ubigeo
  status <- ifelse(is.na(u), NA_character_,
            ifelse(!in_year, "unknown",
            ifelse(in_base & code == u, "same",
            ifelse(in_base, "recoded",
            ifelse(base < year, "created_after_base", "not_in_base")))))
  code[!in_base] <- NA_character_
  list(code = code, status = status)
}

.pad <- function(x, n) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  num <- !is.na(x) & grepl("^[0-9]+$", x)
  x[num] <- formatC(as.integer(x[num]), width = n, flag = "0")
  x
}
