.fa <- new.env(parent = emptyenv())

.ids <- c("enaho", "endes", "ena", "epen", "enapres", "enut", "enares", "eea", "escale", "cpv2017")

# Every error carries a class, so callers can catch one kind with tryCatch()
# instead of parsing the message.
.abort <- function(kind, msg, ...) {
  stop(structure(
    class = c(paste0("faperu_error_", kind), "faperu_error", "error", "condition"),
    list(message = sprintf(msg, ...), call = NULL)
  ))
}

.warn <- function(kind, msg, ...) {
  warning(structure(
    class = c(paste0("faperu_warning_", kind), "faperu_warning", "warning", "condition"),
    list(message = sprintf(msg, ...), call = NULL)
  ))
}

.or <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

.sha256 <- function(path) digest::digest(file = path, algo = "sha256")

.check_survey <- function(survey) {
  if (!is.character(survey) || length(survey) != 1L || is.na(survey)) {
    .abort("input", "`survey` must be one name, for example \"enaho\".")
  }
  s <- tolower(survey)
  if (!s %in% .ids) {
    .abort("survey", "Unknown survey \"%s\". Available: %s.", survey, paste(.ids, collapse = ", "))
  }
  s
}

.load <- function(survey) {
  survey <- .check_survey(survey)
  if (is.null(.fa[[survey]])) {
    path <- system.file("catalog", paste0(survey, ".yaml"), package = "faperu", mustWork = TRUE)
    .fa[[survey]] <- yaml::read_yaml(path)
  }
  .fa[[survey]]
}

#' Cache folder
#'
#' Without arguments, returns the current cache folder. With `path`, changes
#' it for the session. The default comes from the `FAPERU_CACHE` environment
#' variable or, if unset, from [tools::R_user_dir()].
#'
#' If you already have the microdata on disk with the same layout
#' (`<SURVEY>/<year>/<file>.zip`), point the cache there and [fa_download()]
#' will reuse it.
#'
#' @param path New folder, or `NULL` to only query.
#' @return The cache path (invisibly when it is changed).
#' @examples
#' fa_cache()
#' @export
fa_cache <- function(path = NULL) {
  if (!is.null(path)) {
    options(faperu.cache = normalizePath(path, mustWork = FALSE))
    return(invisible(getOption("faperu.cache")))
  }
  p <- getOption("faperu.cache")
  if (is.null(p)) p <- Sys.getenv("FAPERU_CACHE", "")
  if (!nzchar(p)) p <- tools::R_user_dir("faperu", "cache")
  p
}
