# faperu <img src="man/figures/logo.png" align="right" height="190" alt="faperu" />

**Las encuestas y censos oficiales del Perú en R, con una sola forma de pedirlos.**
*Peru's official surveys and censuses in R, asked for one way.*

faperu baja, verifica, lee y pondera diez fuentes oficiales del INEI y del MINEDU. Está pensado
para quien investiga y necesita cifras correctas sin pelear con los archivos: economistas,
salubristas, educadores y funcionarios, no solo programadores.

## Instalar

```r
install.packages("remotes")
remotes::install_github("Andre031222/peru-official-surveys-r")
```

Cuando el paquete esté en CRAN bastará `install.packages("faperu")`. ¿Primera vez con R? La guía
[Instalar paso a paso](articles/instalar.html) empieza desde cero.

## En tres líneas

```r
library(faperu)
s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
survey::svymean(~I(pobreza < 3), fa_design(s, "enaho"))
```

Baja la Sumaria de la ENAHO 2024, la lee y estima la proporción de hogares pobres con su error
estándar, usando el diseño muestral del INEI.

## Qué hace

<div class="fa-cards">
<div class="fa-card"><b>Encontrar</b>Las diez fuentes, sus años y sus 3092 módulos, sin descargar nada. <code>fa_catalog()</code></div>
<div class="fa-card"><b>Bajar</b>Cuatro archivos a la vez, reanuda los cortes y comprueba cada uno con SHA-256. <code>fa_download()</code></div>
<div class="fa-card"><b>Leer</b>Stata, SPSS, CSV o DBF, solo las columnas que pides, con tildes y ceros intactos. <code>fa_read()</code></div>
<div class="fa-card"><b>Ponderar</b>El diseño muestral de cada encuesta, verificado en las fichas técnicas. <code>fa_design()</code></div>
<div class="fa-card"><b>Ubicar</b>El ubigeo de 2004 a 2025 llevado al marco del Censo 2017. <code>fa_ubigeo()</code></div>
</div>

## Las diez fuentes

<div class="fa-cards">
<div class="fa-card"><b><span class="dot" style="background:#0d9488"></span>ENAHO</b>Hogares, pobreza e ingresos · 2004-2025</div>
<div class="fa-card"><b><span class="dot" style="background:#e11d48"></span>ENDES</b>Salud materna e infantil · 2010-2025</div>
<div class="fa-card"><b><span class="dot" style="background:#d97706"></span>ENA</b>Producción agropecuaria · 2014-2025</div>
<div class="fa-card"><b><span class="dot" style="background:#2563eb"></span>EPEN</b>Empleo e informalidad · 2001-2026</div>
<div class="fa-card"><b><span class="dot" style="background:#7c3aed"></span>ENAPRES</b>Programas y servicios públicos · 2010-2025</div>
<div class="fa-card"><b><span class="dot" style="background:#0d9488"></span>ENUT</b>Uso del tiempo · 2010, 2022, 2024</div>
<div class="fa-card"><b><span class="dot" style="background:#e11d48"></span>ENARES</b>Violencia y relaciones sociales · 2013-2024</div>
<div class="fa-card"><b><span class="dot" style="background:#d97706"></span>EEA</b>Empresas y producción · 2001-2025</div>
<div class="fa-card"><b><span class="dot" style="background:#2563eb"></span>Censo Educativo</b>Escuelas y matrícula · 2004-2025</div>
<div class="fa-card"><b><span class="dot" style="background:#7c3aed"></span>Censos 2017</b>Población y vivienda, vía REDATAM</div>
</div>

Las cifras de cada fuente, con tablas y gráficos, están en [Las diez fuentes, en cifras](articles/fuentes.html).
Para buscar un módulo y copiar su código sin instalar nada, usa el [explorador en línea](http://127.0.0.1:8099/explore).

## Comprobado

- 757 archivos comparados en Stata, SPSS y CSV: ninguno perdió ni partió filas.
- Leer 8 de las 1425 columnas del módulo de empleo de la ENAHO 2024 toma 0,7 s en vez de 11,6 s.
- `R CMD check` sin errores ni avisos y más de 200 pruebas.

faperu es independiente: no está afiliado al INEI ni al MINEDU y nunca redistribuye microdatos;
todo se baja de la fuente oficial.

*faperu downloads, verifies, reads and weights ten official Peruvian data sources. Independent of
INEI and MINEDU.*
