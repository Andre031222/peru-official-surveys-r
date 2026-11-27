# How fast is faperu, and which way of getting the data is best?
#
# Three questions:
#   1. Download: how long each format takes, and whether downloading several
#      modules at once is faster than one after the other.
#   2. Read: CSV, Stata or SPSS, the whole file or only a few variables.
#   3. Fidelity: do the three formats give the same numbers, and which keep
#      the labels?
#
# Everything is downloaded fresh into a temporary folder, so the times are
# real downloads; the folder is removed at the end. It takes 5 to 10 minutes
# and moves about 400 MB. Run it with
#
#   Rscript -e 'source(system.file("scripts", "benchmark.R", package = "faperu"))'
#
# and the tables are also written to FAPERU_OUT (default: working directory).

library(faperu)
options(faperu.progress = FALSE)
out_dir <- Sys.getenv("FAPERU_OUT", getwd())
bench_cache <- file.path(tempdir(), "faperu-bench")
dir.create(bench_cache, showWarnings = FALSE)
reps <- as.integer(Sys.getenv("FAPERU_REPS", "3"))

# Modules served in CSV, Stata and SPSS, from narrow to wide. `cols` are the
# few variables a typical analysis needs.
cases <- list(
  list(label = "ENARES 2024 households", survey = "enares", year = 2024, module = "1941",
       file = NULL, cols = c("conglome", "ccdd", "area", "factor_viv")),
  list(label = "ENUT 2024 residents", survey = "enut", year = 2024, module = "1850",
       file = NULL, cols = c("cong", "ubigeo", "factorfinal")),
  list(label = "EPEN 2024 annual", survey = "epen", year = 2024, module = "76",
       series = "departamentos", period = "^Anual - \\(Ene-Dic\\)$", file = NULL,
       cols = c("conglomerado", "ccdd", "estrato", "fac300_anual", "ocup300")),
  list(label = "ENAHO 2024 employment", survey = "enaho", year = 2024, module = "5",
       series = "anual", file = "500", cols = c("conglome", "vivienda", "hogar", "codperso",
                                                 "ubigeo", "estrato", "ocu500", "fac500a"))
)

timed <- function(expr) {
  t0 <- proc.time()[["elapsed"]]
  force(expr)
  proc.time()[["elapsed"]] - t0
}

peak_mb <- function(expr) {
  invisible(gc(reset = TRUE))
  before <- sum(gc()[, 2])
  force(expr)
  sum(gc()[, 6]) - before
}

args_of <- function(cs, format) {
  list(survey = cs$survey, year = cs$year, module = cs$module, series = cs$series,
       period = cs$period, format = format, cache = bench_cache)
}

# 1. Download, one format at a time ----------------------------------------
dl <- list()
for (cs in cases) for (f in c("CSV", "STATA", "SPSS")) {
  d <- suppressMessages(do.call(fa_download, args_of(cs, f)))
  dl[[length(dl) + 1L]] <- data.frame(case = cs$label, format = f, MB = round(d$bytes / 1e6, 1),
                                      seconds = round(d$seconds, 1),
                                      MB_s = round(d$bytes / 1e6 / max(d$seconds, 0.01), 1))
  cat(sprintf("download %-24s %-5s %6.1f MB %6.1f s\n", cs$label, f, d$bytes / 1e6, d$seconds))
}
dl <- do.call(rbind, dl)

# Several modules: one connection versus four at a time.
par_cache <- file.path(tempdir(), "faperu-bench-par")
mods <- fa_catalog("enut", 2024)$module
one <- withr::with_options(list(faperu.connections = 1L), timed(suppressMessages(
  fa_download("enut", 2024, mods, format = "SPSS", cache = file.path(par_cache, "one")))))
four <- withr::with_options(list(faperu.connections = 4L), timed(suppressMessages(
  fa_download("enut", 2024, mods, format = "SPSS", cache = file.path(par_cache, "four")))))
parallel <- data.frame(modules = length(mods), one_at_a_time_s = round(one, 1),
                       four_at_a_time_s = round(four, 1), speedup = round(one / four, 1))
cat(sprintf("\n%d ENUT modules: %.1f s one at a time, %.1f s four at a time\n", length(mods), one, four))
unlink(par_cache, recursive = TRUE)

# 2. Read --------------------------------------------------------------------
rd <- list()
for (cs in cases) {
  for (f in c("CSV", "STATA", "SPSS")) {
    a <- c(args_of(cs, f), list(file = cs$file))
    # The first call unpacks the zip; leave that out of the timing.
    invisible(do.call(fa_variables, a))
    engines <- if (f == "CSV") c("data.table", "base") else "haven"
    for (eng in engines) {
      # Set and put back by hand: this script runs at top level, where
      # withr::local_options() would leave a global deferred event.
      old_opt <- options(faperu.csv_engine = if (eng == "haven") "auto" else eng)
      for (what in c("all", "cols")) {
        aa <- if (what == "cols") c(a, list(cols = cs$cols)) else a
        x <- NULL
        mem <- peak_mb(x <- do.call(fa_read, aa))
        secs <- median(vapply(seq_len(reps), function(i) timed(do.call(fa_read, aa)), numeric(1)))
        rd[[length(rd) + 1L]] <- data.frame(
          case = cs$label, format = f, engine = eng, variables = what,
          rows = nrow(x), cols = ncol(x), seconds = round(secs, 2), peak_MB = round(mem),
          object_MB = round(as.numeric(utils::object.size(x)) / 1e6, 1),
          labels = sum(vapply(x, function(v) !is.null(attr(v, "label")), logical(1))))
        cat(sprintf("read %-24s %-5s %-10s %-4s %7d x %4d  %6.2f s  %5.0f MB\n", cs$label, f, eng,
                    what, nrow(x), ncol(x), secs, mem))
      }
      options(old_opt)
    }
  }
}
rd <- do.call(rbind, rd)

# 3. Do the formats agree? ---------------------------------------------------
fid <- list()
for (cs in cases) {
  get <- function(f) {
    withr::with_options(list(faperu.csv_engine = "auto"),
      do.call(fa_read, c(args_of(cs, f), list(file = cs$file, cols = cs$cols))))
  }
  x <- lapply(c(CSV = "CSV", STATA = "STATA", SPSS = "SPSS"), get)
  same <- function(a, b) all(vapply(cs$cols, function(n) {
    u <- a[[n]]; v <- b[[n]]
    if (is.numeric(unclass(u)) && is.numeric(unclass(v))) return(isTRUE(all.equal(as.numeric(u), as.numeric(v))))
    identical(trimws(as.character(u)), trimws(as.character(v)))
  }, logical(1)))
  fid[[length(fid) + 1L]] <- data.frame(case = cs$label, csv_vs_stata = same(x$CSV, x$STATA),
                                        csv_vs_spss = same(x$CSV, x$SPSS),
                                        stata_vs_spss = same(x$STATA, x$SPSS))
}
fid <- do.call(rbind, fid)

unlink(bench_cache, recursive = TRUE)

cat("\nDownload\n"); print(dl, row.names = FALSE)
cat("\nParallel download\n"); print(parallel, row.names = FALSE)
cat("\nRead (median of", reps, "runs)\n"); print(rd, row.names = FALSE)
cat("\nSame values across formats\n"); print(fid, row.names = FALSE)

stamp <- format(Sys.Date())
write.csv(dl, file.path(out_dir, sprintf("faperu-bench-download-%s.csv", stamp)), row.names = FALSE)
write.csv(rd, file.path(out_dir, sprintf("faperu-bench-read-%s.csv", stamp)), row.names = FALSE)
write.csv(fid, file.path(out_dir, sprintf("faperu-bench-fidelity-%s.csv", stamp)), row.names = FALSE)
write.csv(parallel, file.path(out_dir, sprintf("faperu-bench-parallel-%s.csv", stamp)), row.names = FALSE)
cat("\nTables saved in", out_dir, "\n")
