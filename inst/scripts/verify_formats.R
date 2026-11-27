# Do the formats agree? A check against truncated or split rows.
#
# INEI publishes most modules as Stata, SPSS and CSV. If faperu reads them
# right, every data file has the same rows and columns in all of them. This
# script downloads each format of a set of modules from every INEI survey
# (latest year and an older one), reads every data file and compares. For the
# School Census, which comes in one format, each DBF is checked against the
# record count written in its own header, and the 2017 Census against the
# official population. Besides the counts, every column is compared through
# a fingerprint of its sorted values.
#
#   Rscript -e 'source(system.file("scripts", "verify_formats.R", package = "faperu"))'
#
# It moves about 1.5 GB the first time (into the faperu cache; later runs
# reuse it) and saves the table as CSV in FAPERU_OUT. The ESCALE school
# registers (Padron, Padlocal, any year) are left out because they hold
# personal data of school heads.

library(faperu)
options(faperu.progress = FALSE)
out_dir <- Sys.getenv("FAPERU_OUT", getwd())

# survey, year, modules (NULL = all of that year), series, period
sets <- list(
  list("enaho", 2024, c("1", "2", "3", "4", "5", "34"), "anual"),
  list("enaho", 2015, c("2", "34"), "anual"),
  list("endes", 2024, c("1629", "1631", "1638")),
  list("endes", 2015, c("1629", "1638")),
  list("ena", 2024, c("1893", "1911")),
  list("ena", 2016, NULL, NULL, "."),
  list("epen", 2024, c("76"), "departamentos", "^Anual - \\(Ene-Dic\\)$"),
  list("epen", 2025, NULL, "ciudades", "^Trimestre1$"),
  list("epen", 2022, c("76"), "lima"),
  list("enapres", 2024, NULL),
  list("enapres", 2023, c("1815", "1816", "1820")),
  list("enut", 2024, NULL),
  list("enut", 2010, NULL),
  list("enares", 2024, NULL),
  list("enares", 2019, NULL),
  list("eea", 2024, NULL),
  list("eea", 2015, c("838", "840"))
)

read_all <- function(zip, fmt) {
  files <- faperu:::.zip_files(zip, format = fmt)
  # Stems are compared without case, dashes or underscores ("enaho_tabla" and "enaho-tabla").
  lapply(stats::setNames(files, gsub("[^a-z0-9]", "", tolower(sub("\\.[^.]+$", "", basename(files))))), function(f) {
    w <- character()
    x <- withCallingHandlers(faperu:::.read_file(f),
                             warning = function(c) { w <<- c(w, conditionMessage(c)); invokeRestart("muffleWarning") })
    # Text read with the wrong encoding shows up as "Ã" plus a symbol (mojibake).
    chr <- vapply(x, is.character, logical(1))
    moji <- sum(vapply(x[chr], function(v) sum(grepl("\u00c3[\u0080-\u00bf]", v), na.rm = TRUE), numeric(1)))
    if (moji > 0) w <- c(w, sprintf("%d values look like mojibake", moji))
    # Each column is reduced to a fingerprint of its sorted values, so formats
    # can be compared even when INEI sorted the rows differently.
    nm <- tolower(names(x))
    fp <- stats::setNames(vapply(x, fingerprint, character(1)), nm)
    list(rows = nrow(x), cols = ncol(x), names = nm, ext = tolower(sub("^.*\\.", "", f)),
         warn = paste(w, collapse = " | "), fp = fp, path = f)
  })
}

# Values are made comparable across formats: a code stored as text in one
# format and as a number in another counts as the same, text loses the
# padding SPSS adds and an empty string is a missing value.
plain <- function(v) {
  v <- if (is.factor(v)) as.character(v) else unclass(v)
  attributes(v) <- NULL
  if (is.character(v)) {
    v <- trimws(v)
    v[!is.na(v) & v == ""] <- NA
    n <- suppressWarnings(as.numeric(v))
    if (all(is.na(n) == is.na(v))) v <- n
  }
  if (is.logical(v) || is.numeric(v)) v <- as.double(v)
  v
}

# Numbers go to 7 significant digits: Stata often stores coordinates and
# factors as 4-byte floats, which is all the precision they have.
fingerprint <- function(v) {
  v <- plain(v)
  if (is.numeric(v)) v <- as.character(signif(v, 7))
  digest::digest(sort(v, na.last = TRUE, method = "radix"))
}

# Why does a column differ between two formats? Each answer is a known way
# INEI's own files differ; anything else is reported as "other" to look at.
classify <- function(a, b) {
  a <- plain(a); b <- plain(b)
  if (is.numeric(a) && is.numeric(b) && sum(is.na(a)) == sum(is.na(b))) {
    x <- sort(a); y <- sort(b)
    if (all(abs(x - y) <= 1e-5 * pmax(1, abs(x)))) return("float precision")
  }
  ta <- table(a); tb <- table(b)
  k <- union(names(ta), names(tb))
  na_ <- as.numeric(ta[k]); nb_ <- as.numeric(tb[k]); na_[is.na(na_)] <- 0; nb_[is.na(nb_)] <- 0
  d <- k[na_ != nb_]
  only_a <- d[nb_[match(d, k)] == 0]; only_b <- d[na_[match(d, k)] == 0]
  if (is.numeric(a) && is.numeric(b) && length(d) && length(d) <= 5 && setequal(d, c(only_a, only_b))) {
    # A value present in one format is missing in the other: a code for
    # "no answer" (99, 999999) kept in the CSV and marked as missing in Stata or SPSS.
    if (sum(is.na(b)) - sum(is.na(a)) == sum(na_[match(only_a, k)]) - sum(nb_[match(only_b, k)])) {
      return(paste("missing code", paste(utils::head(d, 3), collapse = "/")))
    }
  }
  if (is.character(a) && is.character(b) && sum(is.na(a)) == sum(is.na(b))) {
    w <- min(max(nchar(a), na.rm = TRUE), max(nchar(b), na.rm = TRUE))
    cut <- function(v) sort(trimws(substr(v, 1, w)), method = "radix")
    ascii <- function(v) gsub("[^ -~]", "?", v)
    if (identical(cut(a), cut(b))) return(sprintf("text cut at %d characters", w))
    if (identical(sort(ascii(a), method = "radix"), sort(ascii(b), method = "radix"))) return("accented letters written differently")
    if (identical(cut(ascii(a)), cut(ascii(b)))) return(sprintf("text cut at %d characters", w))
    # A line break inside a field of a CSV without quotes can only be
    # mended by joining the line with a space.
    flat <- function(v) sort(gsub("\\s+", " ", v), method = "radix")
    if (identical(flat(a), flat(b))) return("line breaks in text became spaces")
    # Stata counts the width in bytes, and an accented letter takes two: a
    # 50-byte text loses one letter per accent. Compare a few letters shorter.
    w <- max(1L, w - 10L)
    if (identical(cut(ascii(a)), cut(ascii(b)))) return(sprintf("text cut at %d bytes, accents written differently", w + 10L))
  }
  # Same rows in the same order, and every character that differs sits where
  # one of the two files has an accent ("PRODUCCION" in Stata, "PRODUCCIÓN"
  # in SPSS): INEI wrote the accents differently in its own files.
  if (is.character(a) && is.character(b) && length(a) == length(b)) {
    a2 <- trimws(a); b2 <- trimws(b)
    a2[is.na(a2)] <- ""; b2[is.na(b2)] <- ""
    ok <- vapply(seq_along(a2), function(i) {
      if (a2[i] == b2[i]) return(TRUE)
      x <- strsplit(a2[i], "")[[1]]; y <- strsplit(b2[i], "")[[1]]
      # The shorter text is the one cut by the format (Stata widths are in bytes).
      n <- min(length(x), length(y))
      if (abs(length(x) - length(y)) > 12) return(FALSE)
      x <- x[seq_len(n)]; y <- y[seq_len(n)]
      d <- x != y
      all(grepl("[^ -~]", x[d]) | grepl("[^ -~]", y[d]) | x[d] %in% c("A", "E", "I", "O", "U", "N") | y[d] %in% c("A", "E", "I", "O", "U", "N"))
    }, logical(1))
    if (all(ok)) return("accents written differently in one format (as published)")
    # A lookup table whose duplicated codes carry different text in each
    # file (ENAHO ciuo88: "TECNICO"/"TECMICO"): up to 0.1 % of the rows.
    if (sum(!ok) <= max(5, 0.001 * length(ok))) return(sprintf("text differs in %d of %d rows (INEI lookup table, as published)", sum(!ok), length(ok)))
  }
  "other"
}

compare_values <- function(fs) {
  if (length(fs) < 2) return(NA_character_)
  ref <- fs[[1]]
  out <- character()
  for (k in seq_along(fs)[-1]) {
    oth <- fs[[k]]
    common <- intersect(names(ref$fp), names(oth$fp))
    d <- common[ref$fp[common] != oth$fp[common]]
    if (!length(d)) next
    # Read again only the columns that differ, and say why.
    a <- faperu:::.read_file(ref$path, cols = d)
    b <- faperu:::.read_file(oth$path, cols = d)
    why <- vapply(d, function(v) classify(a[[v]], b[[v]]), character(1))
    grp <- tapply(d, why, function(z) paste0(paste(utils::head(z, 4), collapse = " "), if (length(z) > 4) sprintf(" +%d", length(z) - 4)))
    out <- c(out, sprintf("%s vs %s: %s", names(fs)[1], names(fs)[k], paste(sprintf("%s (%s)", names(grp), grp), collapse = ", ")))
  }
  if (length(out)) paste(out, collapse = "; ") else "same"
}

rows <- list()
for (st in sets) {
  survey <- st[[1]]; year <- st[[2]]
  cat_ <- fa_catalog(survey, year)
  if (length(st) >= 4 && !is.null(st[[4]])) cat_ <- cat_[cat_$series == st[[4]], ]
  if (length(st) >= 5) cat_ <- cat_[grepl(st[[5]], cat_$period), ]
  if (!is.null(st[[3]])) cat_ <- cat_[cat_$module %in% st[[3]], ]
  for (i in seq_len(nrow(cat_))) {
    m <- cat_[i, ]
    fmts <- intersect(c("STATA", "SPSS", "CSV"), strsplit(m$formats, " ")[[1]])
    got <- list()
    for (f in fmts) {
      r <- tryCatch({
        d <- suppressMessages(suppressWarnings(fa_download(survey, year, m$module, format = f,
                                                           series = m$series, period = paste0("^", gsub("([][{}()+*^$|\\\\?.-])", "\\\\\\1", m$period), "$"))))
        read_all(d$path, f)
      }, error = function(e) conditionMessage(e))
      got[[f]] <- r
    }
    # Pair the data files by name across formats.
    ok_f <- Filter(is.list, got)
    stems <- unique(unlist(lapply(ok_f, names)))
    for (s in stems) {
      g <- function(f, what) if (!is.null(ok_f[[f]][[s]])) ok_f[[f]][[s]][[what]] else NA
      r <- data.frame(survey = survey, year = year, module = m$module, series = m$series, file = s,
                      rows_stata = g("STATA", "rows"), rows_spss = g("SPSS", "rows"), rows_csv = g("CSV", "rows"),
                      cols_stata = g("STATA", "cols"), cols_spss = g("SPSS", "cols"), cols_csv = g("CSV", "cols"),
                      stringsAsFactors = FALSE)
      rr <- c(r$rows_stata, r$rows_spss, r$rows_csv); cc <- c(r$cols_stata, r$cols_spss, r$cols_csv)
      r$formats <- sum(!is.na(rr))
      have <- Filter(Negate(is.null), lapply(stats::setNames(names(ok_f), names(ok_f)), function(f) ok_f[[f]][[s]]))
      r$values <- compare_values(have)
      r$match <- if (r$formats < 2) "single" else if (length(unique(rr[!is.na(rr)])) == 1 && length(unique(cc[!is.na(cc)])) == 1) "OK" else "DIFF"
      # When the columns differ, say which ones: INEI's own files sometimes do
      # (ENA 2016 has CCCP and NOMBRECP only in the SPSS file).
      nm <- Filter(Negate(is.null), lapply(names(ok_f), function(f) ok_f[[f]][[s]]$names))
      extra <- if (length(nm) > 1) setdiff(Reduce(union, nm), Reduce(intersect, nm)) else character()
      if (length(extra)) {
        has <- vapply(names(ok_f), function(f) !is.null(ok_f[[f]][[s]]), logical(1))
        who <- vapply(names(ok_f)[has], function(f) paste0(f, ":", paste(intersect(extra, ok_f[[f]][[s]]$names), collapse = "+")), "")
        extra_note <- paste("columns only in some formats (as published):", paste(who, collapse = " "))
      } else extra_note <- NULL
      r$note <- paste(c(extra_note, unlist(lapply(names(ok_f), function(f) { w <- g(f, "warn"); if (!is.na(w) && nzchar(w)) paste0(f, ": ", w) })),
                        unlist(lapply(names(got), function(f) if (!is.list(got[[f]])) paste0(f, " failed: ", got[[f]])))),
                      collapse = "; ")
      rows[[length(rows) + 1L]] <- r
      cat(sprintf("%-7s %d %-5s %-34s rows %7s %7s %7s  cols %4s %4s %4s  %s %s\n", survey, year, m$module,
                  substr(s, 1, 34), r$rows_stata, r$rows_spss, r$rows_csv, r$cols_stata, r$cols_spss, r$cols_csv,
                  r$match, substr(paste(r$values, r$note), 1, 90)))
    }
    if (length(stems) == 0L) cat(sprintf("%-7s %d %-5s FAILED: %s\n", survey, year, m$module,
                                         paste(unlist(got), collapse = "; ")))
  }
}
res <- do.call(rbind, rows)

# School Census: one format; each DBF must hold as many rows as its header says.
dbf_records <- function(f) {
  con <- file(f, "rb"); on.exit(close(con))
  b <- readBin(con, "raw", 8)
  sum(as.integer(b[5:8]) * 256^(0:3))
}
esc <- list()
for (y in c(2025, 2015)) {
  m <- fa_catalog("escale", y)
  m <- m[!grepl("padron|padlocal", m$name, ignore.case = TRUE), ]
  pick <- if (y == 2025) m$name[seq(1, nrow(m), by = 6)] else m$name
  for (nm in pick) {
    r <- tryCatch({
      d <- suppressMessages(fa_download("escale", y, nm))
      files <- faperu:::.zip_files(d$path)
      do.call(rbind, lapply(files, function(f) {
        x <- faperu:::.read_file(f)
        hdr <- if (grepl("\\.dbf$", f, ignore.case = TRUE)) dbf_records(f) else NA
        data.frame(survey = "escale", year = y, module = nm, file = basename(f), rows = nrow(x), cols = ncol(x),
                   header_rows = hdr, match = if (is.na(hdr)) "no header" else if (hdr == nrow(x)) "OK" else "DIFF")
      }))
    }, error = function(e) data.frame(survey = "escale", year = y, module = nm, file = NA, rows = NA, cols = NA,
                                      header_rows = NA, match = paste("FAILED:", conditionMessage(e))))
    esc[[length(esc) + 1L]] <- r
    print(r, row.names = FALSE)
  }
}
esc <- do.call(rbind, esc)

cpv <- tryCatch(sum(fa_redatam("freq PERSONA.C5P2")$value), error = function(e) NA)

cat("\nINEI data files compared:", nrow(res), "\n")
print(table(res$match))
cat("Values in the compared rows:\n")
print(table(ifelse(is.na(res$values), "one format", ifelse(res$values == "same", "same", "differ"))))
bad <- res[res$match == "DIFF" | nzchar(res$note) | (!is.na(res$values) & res$values != "same"), ]
if (nrow(bad)) { cat("\nFiles that differ or raised a note:\n"); print(bad, row.names = FALSE) }
cat("\nSchool Census files:", nrow(esc), "-", paste(names(table(esc$match)), table(esc$match), collapse = ", "), "\n")
cat("2017 Census population:", format(cpv, big.mark = ","), if (isTRUE(cpv == 29381884)) "(official)" else "(CHECK)", "\n")

stamp <- format(Sys.Date())
write.csv(res, file.path(out_dir, sprintf("faperu-verify-formats-%s.csv", stamp)), row.names = FALSE)
write.csv(esc, file.path(out_dir, sprintf("faperu-verify-escale-%s.csv", stamp)), row.names = FALSE)
cat("Saved in", out_dir, "\n")
