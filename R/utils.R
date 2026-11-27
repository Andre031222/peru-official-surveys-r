.fa <- new.env(parent = emptyenv())

.ids <- c("enaho", "endes", "ena", "epen", "enapres", "enut", "enares", "eea", "escale", "cpv2017")

# Every error carries a class, so callers can catch one kind with tryCatch()
# instead of parsing the message.
.abort <- function(kind, msg, ...) {
  stop(structure(
    class = c(paste0("faperu_error_", kind), "faperu_error", "error", "condition"),
    list(message = if (...length()) sprintf(msg, ...) else msg, call = NULL)
  ))
}

.warn <- function(kind, msg, ...) {
  warning(structure(
    class = c(paste0("faperu_warning_", kind), "faperu_warning", "warning", "condition"),
    list(message = if (...length()) sprintf(msg, ...) else msg, call = NULL)
  ))
}

.or <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

# Hashing a large zip takes a second; within a session the result is reused
# while the file keeps its size and modification time.
.sha256 <- function(path) {
  info <- file.info(path)[, c("size", "mtime")]
  key <- normalizePath(path, mustWork = FALSE)
  memo <- .fa$.sha[[key]]
  if (!is.null(memo) && identical(memo$info, info)) return(memo$sha)
  sha <- digest::digest(file = path, algo = "sha256")
  if (is.null(.fa$.sha)) .fa$.sha <- list()
  .fa$.sha[[key]] <- list(info = info, sha = sha)
  sha
}

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

# Forget what was added to a catalog during the session (used by the tests).
.fa_reset <- function(survey = NULL) {
  rm(list = intersect(.or(survey, ls(.fa)), ls(.fa)), envir = .fa)
  invisible(NULL)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Stata and SPSS columns come as labelled vectors; the code is what we need.
.num <- function(x) as.numeric(unclass(x))

.need <- function(pkg, why) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    .abort("missing_package", "Package '%s' is needed %s. Install it with install.packages(\"%s\").",
           pkg, why, pkg)
  }
}

# Column lookup that ignores case, since INEI files mix both.
.col <- function(data, names) {
  hit <- match(tolower(names), tolower(colnames(data)))
  hit <- hit[!is.na(hit)]
  if (length(hit)) colnames(data)[hit[1]] else NULL
}
