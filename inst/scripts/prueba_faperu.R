# Prueba rápida de faperu: las 10 bases, de punta a punta.
#
# Para cada base baja un módulo (o lo toma de la caché si ya está), lee solo
# unas pocas variables, arma el diseño muestral y al final imprime una tabla
# con los tiempos. El Censo 2017 se consulta en REDATAM.
#
# Desde la terminal, con faperu ya instalado:
#   Rscript -e 'source(system.file("scripts", "prueba_faperu.R", package = "faperu"))'
#
# Variables de entorno que cambian lo que hace:
#   FAPERU_FRESH=1     caché vacía y temporal, para medir descargas de verdad;
#                      se borra al final.
#   FAPERU_LOCAL=ruta  una copia de los microdatos que ya tienes en el disco
#                      (con la forma <BASE>/<año>/<archivo>.zip), para no bajarla
#                      de nuevo.
#   FAPERU_CACHE=ruta  la caché de siempre de faperu, si quieres otra.
#
# En RStudio se puede correr todo con Source o bloque por bloque con Ctrl+Enter.
# La primera vez baja unos 80 MB de encuestas y 678 MB del Censo 2017 (REDATAM);
# después casi todo sale de la caché.


# 1. Paquete y opciones ----------------------------------------------------

library(faperu)
options(width = 150)
options(survey.lonely.psu = "adjust", faperu.progress = interactive())
cat("faperu", as.character(packageVersion("faperu")), "\n")


# 2. Caché -----------------------------------------------------------------

copia <- Sys.getenv("FAPERU_LOCAL", "")
if (identical(Sys.getenv("FAPERU_FRESH"), "1")) {
  # Caché vacía: todo se baja de nuevo y los tiempos son de descarga real.
  fa_cache(file.path(tempdir(), "faperu-prueba"))
} else if (nzchar(copia) && dir.exists(copia)) {
  fa_cache(copia)
}
cat("Caché:", fa_cache(), "\n\n")


# 3. Qué se prueba ---------------------------------------------------------

# Un módulo por base y las variables que haría falta para un análisis
# sencillo: identificador, ubicación y diseño (factor, estrato, conglomerado).
pruebas <- list(
  list(base = "enaho", anio = 2024, modulo = "34", serie = "anual", archivo = "Sumaria-2024\\.",
       vars = c("conglome", "vivienda", "hogar", "ubigeo", "estrato", "factor07", "mieperho", "pobreza")),
  list(base = "endes", anio = 2024, modulo = "1629", archivo = "RECH0",
       vars = c("hhid", "hv001", "hv022", "hv005", "ubigeo")),
  list(base = "ena", anio = 2024, modulo = "1893", archivo = "CARATULA",
       vars = c("ccdd", "nsegm", "estrato", "resfin", "factor_productor")),
  list(base = "epen", anio = 2024, modulo = "76", serie = "departamentos", periodo = "^Anual - \\(Ene-Dic\\)$",
       vars = c("conglomerado", "ccdd", "estrato", "area", "fac300_anual")),
  list(base = "enapres", anio = 2024, modulo = "1856",
       vars = c("conglomerado", "ccdd", "area", "resfin", "factor")),
  list(base = "enut", anio = 2024, modulo = "1849",
       vars = c("cong", "ubigeo", "area", "factorfinal")),
  list(base = "enares", anio = 2024, modulo = "1941",
       vars = c("conglome", "ccdd", "area", "factor_viv")),
  list(base = "eea", anio = 2024, modulo = "2042",
       vars = c("iruc", "ciiu", "ccdd", "factor_exp")),
  # Del Censo Educativo se baja la matrícula; el padrón no, porque trae datos
  # personales de directores que no necesitamos.
  list(base = "escale", anio = 2025, modulo = "01_Matricula_01",
       vars = c("cod_mod", "cuadro", "d01", "d02"))
)

# Cuánto tarda una expresión, en segundos.
cronometrar <- function(expr) {
  t0 <- proc.time()[["elapsed"]]
  valor <- force(expr)
  list(valor = valor, s = proc.time()[["elapsed"]] - t0)
}


# 4. Correr cada prueba ----------------------------------------------------

probar <- function(p) {
  fila <- data.frame(base = p$base, anio = p$anio, modulo = p$modulo, descarga = NA_character_,
                     MB = NA_real_, s_descarga = NA_real_, s_lectura = NA_real_, filas = NA_integer_,
                     variables = NA_integer_, diseno = NA_character_, problema = "",
                     stringsAsFactors = FALSE)
  args <- list(survey = p$base, year = p$anio, module = p$modulo, series = p$serie, period = p$periodo)
  tryCatch({
    d <- cronometrar(do.call(fa_download, args))
    fila$descarga <- d$valor$status
    fila$MB <- round(d$valor$bytes / 1e6, 1)
    fila$s_descarga <- round(d$s, 1)

    x <- cronometrar(do.call(fa_read, c(args, list(file = p$archivo, cols = p$vars))))
    fila$s_lectura <- round(x$s, 2)
    fila$filas <- nrow(x$valor)
    fila$variables <- ncol(x$valor)

    if (p$base == "escale") {
      fila$diseno <- "censo"
    } else {
      dis <- suppressWarnings(suppressMessages(fa_design(x$valor, p$base)))
      fila$diseno <- paste("N =", format(round(sum(weights(dis))), big.mark = ","))
    }
    fila
  }, error = function(e) {
    fila$problema <- conditionMessage(e)
    fila
  })
}

resultados <- NULL
for (p in pruebas) {
  cat("Probando", p$base, p$anio, "...\n")
  resultados <- rbind(resultados, probar(p))
}

# El Censo 2017 no tiene módulos: se consulta su base REDATAM (678 MB la
# primera vez). Necesita el paquete redatamx.
censo <- if (requireNamespace("redatamx", quietly = TRUE)) {
  tryCatch({
    q <- cronometrar(fa_redatam("freq PERSONA.C5P2"))
    sprintf("población %s (oficial 29 381 884) en %.1f s",
            format(sum(q$valor$value), big.mark = " "), q$s)
  }, error = function(e) paste("problema:", conditionMessage(e)))
} else {
  "sin probar: instala redatamx con install.packages(\"redatamx\")"
}


# 5. Resumen ---------------------------------------------------------------

cat("\nResumen (s = segundos; 'cached' quiere decir que ya estaba en la caché)\n\n")
print(resultados[, setdiff(names(resultados), "problema")], row.names = FALSE)
cat("\nCenso 2017 (REDATAM):", censo, "\n")

fallas <- resultados[nzchar(resultados$problema), ]
if (nrow(fallas)) {
  cat("\nCon problemas:\n")
  for (i in seq_len(nrow(fallas))) cat(" -", fallas$base[i], fallas$anio[i], ":", fallas$problema[i], "\n")
} else {
  cat("\nLas", nrow(resultados), "bases con módulos funcionaron.\n")
}
cat(sprintf("Tiempo total: %.1f s de descarga y %.1f s de lectura.\n",
            sum(resultados$s_descarga, na.rm = TRUE), sum(resultados$s_lectura, na.rm = TRUE)))

# Si la caché era temporal, se borra.
if (identical(Sys.getenv("FAPERU_FRESH"), "1")) unlink(fa_cache(), recursive = TRUE)

# ¿Algún año nuevo publicado que el catálogo todavía no tiene?
nuevos <- tryCatch(fa_check_updates(), error = function(e) NULL)
if (!is.null(nuevos)) {
  n <- nuevos[nuevos$new %in% TRUE, ]
  cat("\nAños en la fuente que no están en el catálogo:",
      if (nrow(n)) paste(tapply(n$year, n$survey, function(y) paste(y, collapse = " ")),
                         names(table(n$survey)), sep = " en ", collapse = "; ") else "ninguno", "\n")
  cat("(faperu igual los baja: los busca en el portal al pedirlos.)\n")
}
