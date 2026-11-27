# Ready indicators. Official values are the ones INEI published, kept here
# so fa_indicator() can show them next to the estimate.
.indicators <- list(
  pobreza_monetaria = list(
    survey = "enaho", label = "Monetary poverty (share of people)",
    recipe = function(year, cache) .recipe_enaho_poverty(year, cache),
    official = list(`2024` = c(national = 0.276, urban = 0.248, rural = 0.393),
                    `2025` = c(national = 0.257, urban = 0.234, rural = 0.355)),
    source = c(`2024` = "INEI, press release of 8 May 2025, https://www.gob.pe/institucion/inei/noticias/1164173",
               `2025` = "INEI, press release of 5 May 2026 (poverty 2025), https://www.gob.pe/institucion/inei/noticias/1387366")
  ),
  pobreza_extrema = list(
    survey = "enaho", label = "Extreme monetary poverty (share of people)",
    recipe = function(year, cache) .recipe_enaho_poverty(year, cache, extreme = TRUE),
    official = list(`2024` = c(national = 0.055),
                    `2025` = c(national = 0.047, rural = 0.114)),
    source = c(`2024` = "INEI, press release of 8 May 2025, https://www.gob.pe/institucion/inei/noticias/1164173",
               `2025` = "INEI, press release of 5 May 2026 (poverty 2025), https://www.gob.pe/institucion/inei/noticias/1387366")
  ),
  desempleo = list(
    survey = "epen", label = "Open unemployment rate (labour force, 14 years and over)",
    recipe = function(year, cache) .recipe_epen(year, cache, "unemployment"),
    official = list(`2024` = c(national = 0.056),
                    `2025` = c(national = 0.049)),
    source = c(`2024` = "INEI, Informe tecnico Empleo Nacional (EPEN), annual 2024, https://www.inei.gob.pe/media/MenuRecursivo/boletines/informe-tecnico_empleonacional.pdf",
               `2025` = "INEI, EPEN 2025, as reported by El Peruano, https://elperuano.pe/noticia/289261-inei-poblacion-ocupada-aumento-15-en-el-ano-2025-a-nivel-nacional")
  ),
  informalidad = list(
    survey = "epen", label = "Informal employment rate (employed, 14 years and over)",
    recipe = function(year, cache) .recipe_epen(year, cache, "informality"),
    official = list(`2024` = c(national = 0.709),
                    `2025` = c(national = 0.702, urban = 0.645, rural = 0.948)),
    source = c(`2024` = "INEI, Informe tecnico Empleo Nacional (EPEN), annual 2024, https://www.inei.gob.pe/media/MenuRecursivo/boletines/informe-tecnico_empleonacional.pdf",
               `2025` = "INEI, EPEN January-December 2025, as reported by Infobae on 1 April 2026, https://www.infobae.com/peru/2026/04/01/inei-confirma-que-7-de-cada-10-trabajadores-en-peru-son-informales-pierden-acceso-a-cts-seguro-y-pension/")
  ),
  anemia_6_35 = list(
    survey = "endes", label = "Anaemia in children 6-35 months (WHO 2024, RM 251-2024-MINSA)",
    recipe = function(year, cache) .recipe_endes_anaemia(year, cache, "who2024"),
    official = list(`2024` = c(national = 0.353, urban = 0.312, rural = 0.447),
                    `2025` = c(national = 0.349, urban = 0.315, rural = 0.432)),
    source = c(`2024` = "INEI, Indicadores de Resultados de los Programas Presupuestales ENDES 2024, https://proyectos.inei.gob.pe/endes/2024/ppr2/Indicadores_de_Resultados_de_los_Programas_Presupuestales_ENDES_2024.pdf",
               `2025` = "INEI, press release on ENDES 2025 (Programas Presupuestales), https://www.gob.pe/institucion/inei/noticias/1392685")
  ),
  anemia_6_35_rm363 = list(
    survey = "endes", label = "Anaemia in children 6-35 months (RM 363-2022-MINSA)",
    recipe = function(year, cache) .recipe_endes_anaemia(year, cache, "rm363"),
    official = list(`2024` = c(national = 0.437, urban = 0.402, rural = 0.519),
                    `2025` = c(national = 0.434)),
    source = c(`2024` = "INEI, Indicadores de Resultados de los Programas Presupuestales ENDES 2024, https://proyectos.inei.gob.pe/endes/2024/ppr2/Indicadores_de_Resultados_de_los_Programas_Presupuestales_ENDES_2024.pdf",
               `2025` = "INEI, ENDES 2025, as reported by Infobae on 18 May 2026, https://www.infobae.com/peru/2026/05/18/desnutricion-cronica-y-anemia-infantil-en-peru-cifras-estancadas-y-avances-minimos-segun-la-endes-2025/")
  ),
  mujeres_productoras = list(
    survey = "ena", label = "Women among agricultural producers",
    recipe = function(year, cache) .recipe_ena_women(year, cache),
    official = list(`2024` = c(national = 0.315),
                    `2025` = c(national = 0.312)),
    source = c(`2024` = "INEI, Productores agropecuarios: principales resultados de la ENA 2018-2019 y 2022-2024, https://www.gob.pe/institucion/inei/informes-publicaciones/6879473",
               `2025` = "INEI, ENA 2025 results, as reported by Infobae on 19 June 2026, https://www.infobae.com/peru/2026/06/19/participacion-femenina-en-el-agro-peruano-baja-a-312-segun-el-inei/")
  )
)

#' List the ready indicators
#'
#' @return A data frame with the indicator `id`, the `survey`, a `label`,
#'   the years with an official figure to compare (`checked_years`) and the
#'   `source` of that figure.
#' @details Milk yield per cow from ENA is not included: INEI publishes no
#'   ENA figure to check it against (MIDAGRI's monthly figures come from
#'   administrative records).
#' @export
#' @examples
#' fa_indicators()
fa_indicators <- function() {
  data.frame(
    id = names(.indicators),
    survey = vapply(.indicators, `[[`, "", "survey"),
    label = vapply(.indicators, `[[`, "", "label"),
    checked_years = vapply(.indicators, function(x) paste(names(x$official), collapse = ", "), ""),
    # The source of the latest official figure.
    source = vapply(.indicators, function(x) unname(x$source[length(x$source)]), ""),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

#' Compute a ready indicator
#'
#' Reads the INEI files with `faperu`, builds the design, restricts it to
#' the indicator's population and calls [fa_estimate()]. Where INEI
#' published the figure, it is returned next to the estimate.
#'
#' @param id Indicator id, see [fa_indicators()].
#' @param year Survey year.
#' @param by Domain passed to [fa_estimate()]: `"national"`, `"area"`,
#'   `"department"`, ... ENA has no urban/rural split.
#' @param cache Folder with the microdata, as in [fa_cache()].
#'   Missing files are downloaded there.
#' @param level Confidence level.
#' @return The [fa_estimate()] table with the columns `indicator`,
#'   `survey`, `year`, `official` (the published value, `NA` if none) and
#'   `source`.
#' @export
#' @examples
#' \dontrun{
#' fa_indicator("pobreza_monetaria", 2024, by = "department")
#' }
fa_indicator <- function(id, year, by = "national", cache = fa_cache(), level = 0.95) {
  if (!is.character(id) || length(id) != 1L || !id %in% names(.indicators)) {
    .abort("unknown_indicator", "Unknown indicator '%s'. See fa_indicators().",
           paste(id, collapse = ", "))
  }
  if (!is.numeric(year) || length(year) != 1L) .abort("bad_input", "`year` must be one year.")
  ind <- .indicators[[id]]
  design <- ind$recipe(as.integer(year), cache)
  out <- fa_estimate(design, "fa_y", type = "prop", by = by, level = level)
  out$var <- id
  off <- ind$official[[as.character(year)]]
  key <- if (by == "national") "national" else out$domain
  out$official <- if (is.null(off)) NA_real_ else unname(off[key])
  out$indicator <- id
  out$survey <- ind$survey
  out$year <- as.integer(year)
  out$source <- if (is.na(ind$source[as.character(year)])) NA_character_ else unname(ind$source[as.character(year)])
  first <- c("indicator", "survey", "year")
  out[, c(first, setdiff(names(out), first))]
}
