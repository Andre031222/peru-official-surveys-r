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
    .fa$crosswalk <- read("crosswalk_cpv2017.csv")
    .fa$legacy <- read("ubigeo_legados_enaho.csv")
  }
  list(districts = .fa$districts, changes = .fa$changes,
       crosswalk = .fa$crosswalk, legacy = .fa$legacy)
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
#' The official INEI district list for one year. It comes from the National
#' Registry of Municipalities (RENAMU) 2004-2025, with three corrections,
#' because RENAMU lists a new district a year or two after its law:
#' a district starts in the year of its creation law when INEI's 2025
#' national directory gives the date; the 2017 list is the 2017 Census frame
#' (1874 districts); and Santa Rosa de Loreto, missing from RENAMU 2025, is
#' added from MINEDU's 2025 school register. Sources are listed in
#' `system.file("ubigeo", "README.md", package = "faperu")`.
#'
#' @param year A year between 2004 and 2025.
#' @return A data frame with `ubigeo`, `distrito`, `provincia`,
#'   `departamento`, `desde`, `hasta`, where `desde` comes from
#'   (`desde_fuente`), the first year in RENAMU and the creation law.
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
#' INEI's separate codes (`CCDD`, `CCPP`, `CCDI`), as in the ENA. Codes are
#' always text padded to six digits, because INEI's CSV files drop the
#' leading zero (`10101` is `010101`).
#'
#' The codes are INEI's. RENIEC and SUNAT number districts differently
#' (INEI puts Callao in `07`, RENIEC in `24`), so do not mix them.
#'
#' With `year` and `base`, it also translates the codes from the coding used
#' in `year` to the coding used in `base`. The natural base is `2017`: the
#' 1874 districts of the 2017 Census, the frame of every INEI survey since
#' 2018. The translation follows, and only follows:
#'
#' * the recodings INEI made when it created the provinces of Datem del
#'   Maranon (2006) and Putumayo (2015), and the Bagua and La Peca swap of
#'   2007, as seen in RENAMU 2004-2025;
#' * for districts created after 2017, the 2017 district that holds their
#'   schools in MINEDU's 2025 school register. This crosswalk has not been
#'   checked law by law yet.
#'
#' Nothing else is guessed. Districts created between 2005 and 2017 have no
#' known parent, and Lambras and Santa Lucia have two, so they get `NA`.
#' Sources and method are in `system.file("ubigeo", "README.md", package =
#' "faperu")`.
#'
#' `ubigeo_status` is one of:
#'
#' * `"same"`: the code means the same district in both years.
#' * `"recoded"`: same district, new code.
#' * `"recoded_partial"`: same name, new code, but the new province also got
#'   new districts at the time, so the old district may have been larger.
#' * `"area_changed"`: same code, but a district was carved out of it between
#'   the two years (from the 2017 crosswalk).
#' * `"to_parent"`: a district created after `base`, given the code of the
#'   district it came from.
#' * `"multi_parent"`: created after `base` out of two districts; `NA`.
#' * `"created_after_base"`: created after `base`, parent unknown; `NA`.
#' * `"legacy"`: an old code INEI surveys used that matches no district
#'   (ENAHO's `120699`); `NA`.
#' * `"unknown"`: not a district in `year`; `NA`.
#'
#' @param data A data frame.
#' @param var Name of the ubigeo column. If `NULL`, it looks for `ubigeo`
#'   and then for `ccdd`, `ccpp` and `ccdi` (any case).
#' @param year Year the data were collected. Needed for `base`, and used to
#'   flag codes that did not exist that year. Years outside 2004-2025 are
#'   moved to the nearest end of the table, with a warning.
#' @param base Year whose coding you want, usually `2017`.
#' @return `data` with the new columns. With `base`, also `ubigeo_base` and
#'   `ubigeo_status`.
#' @examples
#' fa_ubigeo(data.frame(UBIGEO = c("210101", "150101")))
#' fa_ubigeo(data.frame(CCDD = "21", CCPP = "01", CCDI = "01"))
#' fa_ubigeo(data.frame(ubigeo = c("130112", "160109")), year = 2024, base = 2017)
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
    codes <- unique(u[!is.na(u)])
    h <- .harmonise(codes, year, base)
    i <- match(u, codes)
    data$ubigeo_base <- h$code[i]
    data$ubigeo_status <- h$status[i]
  }
  data
}

# Works on distinct codes, one at a time: there are fewer than 2000.
.harmonise <- function(codes, year, base) {
  tb <- .ubigeo_tables()
  ch <- tb$changes
  xw <- tb$crosswalk
  d <- tb$districts
  in_year <- fa_districts(year)$ubigeo
  in_base <- fa_districts(base)$ubigeo
  created <- function(x) min(d$desde[d$ubigeo == x])
  out_code <- rep(NA_character_, length(codes))
  out_status <- rep(NA_character_, length(codes))

  for (j in seq_along(codes)) {
    code <- codes[j]
    partial <- FALSE
    if (!code %in% in_year) {
      # Surveys kept some old codes for a year or two after INEI changed them.
      old <- ch[ch$de == code & ch$anio <= year, , drop = FALSE]
      if (nrow(old) == 1L) {
        code <- old$a
        partial <- !is.na(old$nuevos_en_provincia)
      } else {
        out_status[j] <- if (code %in% tb$legacy$ubigeo_legado) "legacy" else "unknown"
        next
      }
    }
    if (base > year) {
      for (y in seq(year + 1L, base)) {
        hit <- ch[ch$anio == y & ch$de == code, , drop = FALSE]
        if (nrow(hit) == 1L) {
          code <- hit$a
          partial <- partial || !is.na(hit$nuevos_en_provincia)
        }
      }
    } else if (base < year) {
      # Going back, all changes of a year happen at once: in 2007 Bagua took
      # La Peca's old code, so each code moves once per year.
      for (y in rev(seq(base + 1L, year))) {
        hit <- ch[ch$anio == y & ch$a == code, , drop = FALSE]
        if (nrow(hit) == 1L) code <- hit$de
      }
    }

    if (code %in% in_base) {
      out_code[j] <- code
      carved <- xw$ubigeo[xw$ubigeo_cpv2017 == code]
      lo <- min(year, base)
      hi <- max(year, base)
      carved <- carved[vapply(carved, function(x) created(x) > lo && created(x) <= hi, logical(1))]
      out_status[j] <- if (partial) {
        "recoded_partial"
      } else if (code != codes[j]) {
        "recoded"
      } else if (length(carved) > 0L) {
        "area_changed"
      } else {
        "same"
      }
      next
    }
    parents <- xw$ubigeo_cpv2017[xw$ubigeo == code]
    if (length(parents) > 1L) {
      out_status[j] <- "multi_parent"
    } else if (length(parents) == 1L && parents %in% in_base) {
      out_code[j] <- parents
      out_status[j] <- "to_parent"
    } else {
      out_status[j] <- "created_after_base"
    }
  }
  list(code = out_code, status = out_status)
}

.pad <- function(x, n) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  num <- !is.na(x) & grepl("^[0-9]+$", x)
  x[num] <- formatC(as.integer(x[num]), width = n, flag = "0")
  x
}
