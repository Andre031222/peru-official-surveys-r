# faperu <img src="man/figures/logo.png" align="right" height="190" alt="faperu" />

**Las encuestas y censos oficiales del Perú en R, con una sola forma de pedirlos.**

faperu baja, verifica, lee y pondera diez fuentes del INEI y del MINEDU, para que cualquier
persona que investiga obtenga cifras correctas sin pelear con los archivos.

## Instalar

```r
install.packages("remotes")
library(remotes)
install_github("Andre031222/peru-official-surveys-r")
```

Pronto en CRAN, con `install.packages("faperu")`. Si es tu primera vez con R, sigue
[Instalar paso a paso](articles/instalar.html).

## Un ejemplo

```r
library(faperu)
library(survey)

s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
svymean(~I(pobreza < 3), fa_design(s, "enaho"))
```

Baja la Sumaria de la ENAHO 2024, la lee y estima la proporción de hogares pobres con su error
estándar, usando el diseño muestral del INEI.

## Qué hace

<div class="fa-cards">
<div class="fa-card"><b>Encontrar</b>Las diez fuentes, sus años y sus 3092 módulos, sin descargar nada.</div>
<div class="fa-card"><b>Bajar</b>Cuatro archivos a la vez, reanuda los cortes y comprueba cada uno.</div>
<div class="fa-card"><b>Leer</b>Stata, SPSS, CSV o DBF, solo las columnas que pides.</div>
<div class="fa-card"><b>Ponderar</b>El diseño muestral de cada encuesta, verificado en las fichas técnicas.</div>
<div class="fa-card"><b>Ubicar</b>El ubigeo de 2004 a 2025, llevado al marco del Censo 2017.</div>
</div>

## Las diez fuentes

<div class="fa-cards">
<div class="fa-card"><b><span class="dot" style="background:#0d9488"></span>ENAHO</b>Hogares, pobreza e ingresos</div>
<div class="fa-card"><b><span class="dot" style="background:#e11d48"></span>ENDES</b>Salud materna e infantil</div>
<div class="fa-card"><b><span class="dot" style="background:#d97706"></span>ENA</b>Producción agropecuaria</div>
<div class="fa-card"><b><span class="dot" style="background:#2563eb"></span>EPEN</b>Empleo e informalidad</div>
<div class="fa-card"><b><span class="dot" style="background:#7c3aed"></span>ENAPRES</b>Programas y servicios públicos</div>
<div class="fa-card"><b><span class="dot" style="background:#0d9488"></span>ENUT</b>Uso del tiempo</div>
<div class="fa-card"><b><span class="dot" style="background:#e11d48"></span>ENARES</b>Violencia y relaciones sociales</div>
<div class="fa-card"><b><span class="dot" style="background:#d97706"></span>EEA</b>Empresas y producción</div>
<div class="fa-card"><b><span class="dot" style="background:#2563eb"></span>Censo Educativo</b>Escuelas y matrícula</div>
<div class="fa-card"><b><span class="dot" style="background:#7c3aed"></span>Censos 2017</b>Población y vivienda</div>
</div>

Años, módulos y formatos de cada una, en [Las diez fuentes, en cifras](articles/fuentes.html).
