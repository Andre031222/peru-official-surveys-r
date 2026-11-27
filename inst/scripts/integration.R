# End-to-end check of faperu against the real sources.
#
# For each of the ten sources it takes the latest year and an older one and
# goes through the whole path: catalog, download, a second download that has
# to come from the cache, the variable list, a full read, a read of a few
# columns (which must give the same values) and the survey design. The 2017
# Census goes through REDATAM instead, and at the end the INEI portal and
# the ESCALE folders are asked for new years.
#
# Run it from a terminal:
#
#   Rscript -e 'source(system.file("scripts", "integration.R", package = "faperu"))'
#
# The files go to the faperu cache (see fa_cache(), or set FAPERU_CACHE).
# The first run downloads about 300 MB; later runs reuse the cache. The table
# is also saved as CSV in FAPERU_OUT (by default the working directory).
# Nothing personal is read: the ESCALE register of schools (00_Padron) is
# left out on purpose.

library(faperu)
options(survey.lonely.psu = "adjust", faperu.progress = FALSE)
cache <- fa_cache()
out_dir <- Sys.getenv("FAPERU_OUT", getwd())

cases <- read.csv(text = '
survey,year,module,series,period,file
enaho,2024,34,anual,,Sumaria-2024\\.
enaho,2015,34,anual,,Sumaria-2015\\.
endes,2024,1629,,,RECH0
endes,2010,64,,,RECH0
endes,2009,64,,,RECH0
ena,2024,1893,,,CARATULA
ena,2014,772,,,
epen,2024,76,departamentos,^Anual - \\(Ene-Dic\\)$,
epen,2015,76,epe_lima,Ene-Feb-Mar,
epen,2026,76,lima,Nov-Dic-Ene,
enapres,2024,1856,,,
enapres,2015,699,,,
enut,2024,1849,,,
enut,2010,125,,,
enares,2024,1941,,,
enares,2013,739,,,
eea,2024,2042,,,
eea,2013,347,,,
eea,2010,345,,,
escale,2025,01_Matricula_01,,,
escale,2015,02 Mat2100.dbf,,,
', colClasses = "character", na.strings = "")

# NULL instead of NA, so the arguments can be passed straight through.
arg <- function(v) if (is.na(v) || !nzchar(v)) NULL else v

secs <- function(expr) {
  t0 <- proc.time()[["elapsed"]]
  val <- force(expr)
  list(value = val, secs = proc.time()[["elapsed"]] - t0)
}

# Peak memory, in MB, that R needed while evaluating expr.
peak_mb <- function(expr) {
  invisible(gc(reset = TRUE))
  before <- sum(gc()[, 2])
  force(expr)
  sum(gc()[, 6]) - before
}

# The design variables of a survey that are present in a set of names,
# plus the district code.
design_cols <- function(survey, have) {
  dz <- yaml::read_yaml(system.file("catalog", paste0(survey, ".yaml"), package = "faperu"))$diseno
  cand <- unlist(c(dz$peso, dz$estrato, dz$conglomerado, "UBIGEO"))
  re <- grep("^re:", cand, value = TRUE)
  cand <- unique(unlist(strsplit(cand[!startsWith(cand, "re:")], "*", fixed = TRUE)))
  hit <- have[tolower(have) %in% tolower(cand)]
  for (r in re) hit <- c(hit, grep(substring(r, 4), have, value = TRUE, ignore.case = TRUE)[1])
  unique(hit[!is.na(hit)])
}

has_weight <- function(survey, have) {
  w <- unlist(yaml::read_yaml(system.file("catalog", paste0(survey, ".yaml"), package = "faperu"))$diseno$peso)
  any(tolower(have) %in% tolower(w[!startsWith(w, "re:")])) ||
    any(vapply(substring(w[startsWith(w, "re:")], 4), function(r) any(grepl(r, have, ignore.case = TRUE)), logical(1)))
}

run_case <- function(cs) {
  row <- data.frame(survey = cs$survey, year = as.integer(cs$year), module = cs$module,
                    format = NA, MB = NA, download = "FAIL", dl_secs = NA, MB_s = NA,
                    cache = "FAIL", variables = NA, read = "FAIL", rows = NA, cols = NA,
                    read_secs = NA, read_MB = NA, select = "FAIL", sel_cols = NA,
                    sel_secs = NA, sel_MB = NA, design = "FAIL", note = "",
                    stringsAsFactors = FALSE)
  a <- list(survey = cs$survey, year = as.integer(cs$year), module = cs$module,
            series = arg(cs$series), period = arg(cs$period))
  step <- "download"
  res <- tryCatch({
    d <- secs(do.call(fa_download, a))
    row$format <- d$value$format
    row$MB <- round(d$value$bytes / 1e6, 2)
    row$dl_secs <- round(d$value$seconds, 2)
    if (d$value$status != "cached" && d$value$seconds > 0) row$MB_s <- round(row$MB / row$dl_secs, 2)
    row$download <- paste("OK", d$value$status)

    step <- "cache"
    again <- do.call(fa_download, a)
    row$cache <- if (identical(again$status, "cached")) "OK" else paste("FAIL", again$status)

    step <- "variables"
    v <- do.call(fa_variables, c(a, list(file = arg(cs$file))))
    files <- unique(v$file)
    if (length(files) > 1L) {
      # Several tables in the module: take the first one that has design variables.
      f <- Filter(function(f) length(design_cols(cs$survey, v$name[v$file == f])) > 0L, files)
      file <- paste0("^", gsub("([.()])", "\\\\\\1", if (length(f)) f[1] else files[1]), "$")
    } else {
      file <- arg(cs$file)
    }
    v1 <- v[v$file == if (length(files) > 1L) (if (length(f)) f[1] else files[1]) else files[1], ]
    row$variables <- nrow(v1)

    step <- "read"
    full <- NULL
    row$read_MB <- round(peak_mb(full <- secs(do.call(fa_read, c(a, list(file = file))))), 1)
    row$read_secs <- round(full$secs, 2)
    full <- full$value
    row$rows <- nrow(full)
    row$cols <- ncol(full)
    row$read <- "OK"

    step <- "select"
    want <- design_cols(cs$survey, v1$name)
    if (length(want) == 0L) want <- head(v1$name, 3)
    sel <- NULL
    row$sel_MB <- round(peak_mb(sel <- secs(do.call(fa_read, c(a, list(file = file, cols = want))))), 1)
    row$sel_secs <- round(sel$secs, 2)
    sel <- sel$value
    row$sel_cols <- paste(names(sel), collapse = " ")
    same <- identical(nrow(sel), nrow(full)) &&
      all(vapply(names(sel), function(n) isTRUE(all.equal(sel[[n]], full[[n]], check.attributes = FALSE)), logical(1)))
    row$select <- if (same) "OK" else "FAIL differs from full read"

    step <- "design"
    if (cs$survey == "escale") {
      row$design <- "n/a (census)"
    } else {
      w <- character()
      if (!has_weight(cs$survey, v1$name)) {
        # Old EEA files (2001-2011) bring no weight at all; that is the data, not a bug.
        row$design <- "n/a (no weight in the file)"
        return(row)
      }
      ds <- withCallingHandlers(fa_design(sel, cs$survey),
                                warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") },
                                message = function(x) invokeRestart("muffleMessage"))
      pop <- sum(weights(ds))
      row$design <- sprintf("OK N=%s", format(round(pop), big.mark = ","))
      if (length(w)) row$note <- paste(unique(sub("\\.$", "", w)), collapse = "; ")
    }
    row
  }, error = function(e) {
    row$note <- paste0(step, ": ", conditionMessage(e))
    row
  })
  res
}

cat("faperu", as.character(packageVersion("faperu")), "- cache:", cache, "\n\n")
results <- do.call(rbind, lapply(split(cases, seq_len(nrow(cases))), function(cs) {
  r <- run_case(cs)
  cat(sprintf("%-8s %d %-16s download %-14s cache %-4s read %-4s select %-4s design %s\n",
              r$survey, r$year, r$module, r$download, r$cache, r$read, r$select, r$design))
  if (nzchar(r$note)) cat("         note:", r$note, "\n")
  r
}))

# The census has no module files; it is queried in REDATAM.
cpv <- tryCatch({
  q <- secs(fa_redatam("freq PERSONA.C5P2"))
  ok <- sum(q$value$value) == 29381884
  vars <- fa_redatam()
  sprintf("%s total %s (official 29,381,884), %d variables, %.1f s",
          if (ok) "OK" else "FAIL", format(sum(q$value$value), big.mark = ","), nrow(vars), q$secs)
}, error = function(e) paste("FAIL", conditionMessage(e)))
cat(sprintf("%-8s %d %-16s REDATAM %s\n", "cpv2017", 2017L, "-", cpv))

# Update detection: which years each source publishes today.
upd <- secs(fa_check_updates())
cat(sprintf("\nfa_check_updates() took %.1f s\n", upd$secs))
for (s in unique(upd$value$survey)) {
  u <- upd$value[upd$value$survey == s, ]
  yrs <- if (all(is.na(u$year))) "" else sprintf("%d-%d", min(u$year), max(u$year))
  new <- u$year[u$new %in% TRUE]
  cat(sprintf("  %-8s %-12s %-10s %s\n", s, u$status[1], yrs,
              if (length(new)) paste("new:", paste(new, collapse = " ")) else ""))
}

path <- file.path(out_dir, sprintf("faperu-integration-%s.csv", format(Sys.Date())))
write.csv(results, path, row.names = FALSE)
cat("\nSaved", path, "\n")
