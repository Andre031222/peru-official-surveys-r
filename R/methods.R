# Print and summary methods. The objects stay data frames: the class only
# changes how they look at the console. A table that lost the columns a
# method needs (after subsetting by hand) prints as a plain data frame.

.as <- function(x, cls) {
  class(x) <- unique(c(cls, class(x)))
  x
}

.has <- function(x, cols) all(cols %in% names(x))

.plain <- function(x) {
  class(x) <- setdiff(class(x), c("fa_surveys", "fa_catalog", "fa_download", "fa_updates", "fa_estimate", "fa_link"))
  x
}

# Cut long names so a row fits in the console.
.fit <- function(v, used) {
  w <- max(20L, getOption("width", 80L) - used)
  ifelse(nchar(v) > w, paste0(substr(v, 1, w - 1L), "~"), v)
}

.range <- function(y) {
  y <- y[!is.na(y)]
  if (length(y) == 0L) return("-")
  if (min(y) == max(y)) as.character(min(y)) else paste0(min(y), "-", max(y))
}

#' Print and summarise faperu tables
#'
#' [fa_surveys()], [fa_catalog()], [fa_download()] and [fa_check_updates()]
#' return data frames with an extra class, so they print as a short report.
#' They are still data frames: subset, filter or save them as usual, or use
#' [as.data.frame()] to drop the class.
#'
#' @param x,object A table returned by one of those functions.
#' @param n Rows to show.
#' @param ... Passed on to [print.data.frame()].
#' @return `print()` returns `x` invisibly. `summary()` of a catalog returns
#'   a data frame with one row per year: modules, series and formats.
#' @examples
#' fa_surveys()
#' summary(fa_catalog("enut"))
#' @name faperu-methods
NULL

#' @rdname faperu-methods
#' @export
print.fa_surveys <- function(x, ...) {
  if (!.has(x, c("acronym", "name", "from", "to", "modules", "design"))) return(NextMethod())
  cat(sprintf("<faperu: %d official sources of Peru>\n", nrow(x)))
  show <- data.frame(
    survey = x$survey, source = x$acronym,
    years = ifelse(x$from == x$to, x$from, paste0(x$from, "-", x$to)),
    modules = x$modules,
    design = ifelse(x$design, "yes", ifelse(x$type == "censo", "census", "-")),
    name = .fit(x$name, 48L),
    stringsAsFactors = FALSE
  )
  print(show, row.names = FALSE, right = FALSE, ...)
  invisible(x)
}

#' @rdname faperu-methods
#' @export
print.fa_catalog <- function(x, n = 10L, ...) {
  if (!.has(x, c("survey", "year", "module", "name", "formats"))) return(NextMethod())
  surveys <- unique(x$survey)
  head <- if (length(surveys) == 1L) toupper(surveys) else paste(toupper(surveys), collapse = ", ")
  cat(sprintf("<faperu catalog: %s, %d module%s, years %s>\n", head, nrow(x),
              if (nrow(x) == 1L) "" else "s", .range(x$year)))
  if (nrow(x) == 0L) return(invisible(x))
  cols <- intersect(c("year", "series", "period", "module", "name", "formats"), names(x))
  show <- .plain(x)[seq_len(min(n, nrow(x))), cols, drop = FALSE]
  # A column with one value says nothing row by row.
  for (k in c("series", "period")) {
    if (k %in% names(show) && length(unique(x[[k]])) <= 1L) show[[k]] <- NULL
  }
  used <- sum(vapply(setdiff(names(show), "name"), function(k) {
    max(nchar(c(k, as.character(show[[k]])))) + 1L
  }, numeric(1)))
  show$name <- .fit(show$name, used + 2L)
  print(show, row.names = FALSE, right = FALSE, ...)
  if (nrow(x) > n) {
    cat(sprintf("# ... %d more. All rows: as.data.frame(x); by year: summary(x)\n", nrow(x) - n))
  }
  invisible(x)
}

#' @rdname faperu-methods
#' @export
summary.fa_catalog <- function(object, ...) {
  if (!.has(object, c("year", "series", "formats"))) return(summary(.plain(object), ...))
  years <- sort(unique(object$year), decreasing = TRUE)
  out <- data.frame(
    year = years,
    modules = vapply(years, function(y) sum(object$year == y), integer(1)),
    series = vapply(years, function(y) paste(sort(unique(object$series[object$year == y])), collapse = ", "), ""),
    formats = vapply(years, function(y) {
      f <- unlist(strsplit(object$formats[object$year == y], " ", fixed = TRUE))
      paste(intersect(c("STATA", "SPSS", "CSV", "DBF", "ZIP"), f), collapse = " ")
    }, ""),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

#' @rdname faperu-methods
#' @export
print.fa_download <- function(x, ...) {
  if (!.has(x, c("status", "bytes", "seconds", "path"))) return(NextMethod())
  st <- table(factor(x$status, c("cached", "downloaded", "changed")))
  cat(sprintf("<faperu download: %d file%s, %.1f MB, %.1f s>\n", nrow(x),
              if (nrow(x) == 1L) "" else "s", sum(x$bytes, na.rm = TRUE) / 1e6,
              sum(x$seconds, na.rm = TRUE)))
  cat(sprintf("  %d from the cache, %d downloaded, %d changed at the source\n",
              st[["cached"]], st[["downloaded"]], st[["changed"]]))
  show <- data.frame(module = x$module, format = x$format, status = x$status,
                     MB = round(x$bytes / 1e6, 1), file = basename(x$path),
                     stringsAsFactors = FALSE)
  print(show, row.names = FALSE, right = FALSE, ...)
  invisible(x)
}

#' @rdname faperu-methods
#' @export
print.fa_updates <- function(x, ...) {
  if (!.has(x, c("survey", "year", "new", "status"))) return(NextMethod())
  cat("<faperu: years published at the source>\n")
  for (s in unique(x$survey)) {
    r <- x[x$survey == s, , drop = FALSE]
    msg <- switch(r$status[1],
      ok = {
        new <- r$year[r$new %in% TRUE]
        sprintf("%s, %s new: %s", .range(r$year), length(new),
                if (length(new)) paste(new, collapse = " ") else "none")
      },
      unreachable = "the source did not answer",
      "not checked"
    )
    cat(sprintf("  %-8s %s\n", s, msg))
  }
  invisible(x)
}
