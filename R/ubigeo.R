.departments <- c(
  "01" = "Amazonas", "02" = "\u00c1ncash", "03" = "Apur\u00edmac", "04" = "Arequipa",
  "05" = "Ayacucho", "06" = "Cajamarca", "07" = "Callao", "08" = "Cusco",
  "09" = "Huancavelica", "10" = "Hu\u00e1nuco", "11" = "Ica", "12" = "Jun\u00edn",
  "13" = "La Libertad", "14" = "Lambayeque", "15" = "Lima", "16" = "Loreto",
  "17" = "Madre de Dios", "18" = "Moquegua", "19" = "Pasco", "20" = "Piura",
  "21" = "Puno", "22" = "San Mart\u00edn", "23" = "Tacna", "24" = "Tumbes",
  "25" = "Ucayali"
)

#' Standard ubigeo columns
#'
#' Adds a six-digit `ubigeo` and its `department`, `province` and
#' `department_name`. It takes an existing ubigeo column, or builds one from
#' INEI's separate codes (`CCDD`, `CCPP`, `CCDI`), as in the ENA.
#'
#' Harmonising districts across ubigeo versions (districts created after
#' 2017) is not done yet.
#'
#' @param data A data frame.
#' @param var Name of the ubigeo column. If `NULL`, it looks for `ubigeo`
#'   and then for `ccdd`, `ccpp` and `ccdi` (any case).
#' @return `data` with the new columns.
#' @examples
#' fa_ubigeo(data.frame(UBIGEO = c("210101", "150101")))
#' fa_ubigeo(data.frame(CCDD = "21", CCPP = "01", CCDI = "01"))
#' @export
fa_ubigeo <- function(data, var = NULL) {
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
  data
}

.pad <- function(x, n) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  num <- !is.na(x) & grepl("^[0-9]+$", x)
  x[num] <- formatC(as.integer(x[num]), width = n, flag = "0")
  x
}
