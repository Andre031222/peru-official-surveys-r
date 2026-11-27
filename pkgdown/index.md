# faperu <img src="man/figures/logo.png" align="right" height="190" alt="faperu" />

**Las encuestas y censos oficiales del Perú en R, con una sola forma de pedirlos.**

faperu baja, verifica, lee y pondera diez fuentes del INEI y del MINEDU, y las convierte en
cifras con su error, su banda de calidad, tablas y mapas, para que cualquier persona que investiga
obtenga cifras correctas sin pelear con los archivos.

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
<div class="fa-card"><b>Estimar</b>Cada cifra con error estándar, intervalo, CV y la banda de calidad del INEI.</div>
<div class="fa-card"><b>Comprobar</b>Siete indicadores que reproducen las cifras oficiales del INEI 2024.</div>
<div class="fa-card"><b>Mostrar</b>Tablas listas para un artículo y mapas sobre los límites del INEI.</div>
</div>

## Del dato a la cifra oficial

```r
p <- fa_indicator("pobreza_monetaria", 2024, by = "department")
summary(p)
fa_map(p)
```

<img src="img/map_poverty.png" alt="Pobreza monetaria 2024 por departamento" style="max-width:560px;width:100%;display:block;margin:1rem auto" />

Más indicadores, tablas y mapas en la [Galería](articles/galeria.html) y en
[Analizar](articles/analysis.html).

## Las diez fuentes

<div class="table-wrap"><table class="table-modern"><thead><tr><th>Fuente</th><th class="hide-sm">Tema</th><th class="num">Años</th><th class="num">Módulos</th><th>Diseño</th></tr></thead><tbody>
<tr><td><div class="src"><span class="chip" style="background:#0d9488"></span><span><b>ENAHO</b><small>Encuesta Nacional de Hogares</small></span></div></td><td class="hide-sm">Hogares, pobreza e ingresos</td><td class="num">2002–2025</td><td class="num" style="color:#0d9488">722<span class="bar" style="width:3.03rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#e11d48"></span><span><b>ENDES</b><small>Encuesta Demográfica y de Salud Familiar</small></span></div></td><td class="hide-sm">Salud materna e infantil</td><td class="num">2010–2025</td><td class="num" style="color:#e11d48">198<span class="bar" style="width:0.83rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#d97706"></span><span><b>ENA</b><small>Encuesta Nacional Agropecuaria</small></span></div></td><td class="hide-sm">Producción agropecuaria</td><td class="num">2014–2025</td><td class="num" style="color:#d97706">241<span class="bar" style="width:1.01rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#2563eb"></span><span><b>EPEN</b><small>Encuesta Permanente de Empleo Nacional</small></span></div></td><td class="hide-sm">Empleo e informalidad</td><td class="num">2001–2026</td><td class="num" style="color:#2563eb">953<span class="bar" style="width:4.00rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#7c3aed"></span><span><b>ENAPRES</b><small>Encuesta Nacional de Programas Presupuestales</small></span></div></td><td class="hide-sm">Programas y servicios públicos</td><td class="num">2010–2025</td><td class="num" style="color:#7c3aed">204<span class="bar" style="width:0.85rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#0d9488"></span><span><b>ENUT</b><small>Encuesta Nacional de Uso del Tiempo</small></span></div></td><td class="hide-sm">Uso del tiempo</td><td class="num">2010–2024</td><td class="num" style="color:#0d9488">13<span class="bar" style="width:0.25rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#e11d48"></span><span><b>ENARES</b><small>Encuesta Nacional sobre Relaciones Sociales</small></span></div></td><td class="hide-sm">Violencia y relaciones sociales</td><td class="num">2013–2024</td><td class="num" style="color:#e11d48">77<span class="bar" style="width:0.32rem"></span></td><td><span class="badge-soft ok">verificado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#d97706"></span><span><b>EEA</b><small>Encuesta Económica Anual</small></span></div></td><td class="hide-sm">Empresas y producción</td><td class="num">2001–2025</td><td class="num" style="color:#d97706">604<span class="bar" style="width:2.53rem"></span></td><td><span class="badge-soft mid">aproximado</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#2563eb"></span><span><b>CE</b><small>Censo Educativo (MINEDU)</small></span></div></td><td class="hide-sm">Escuelas y matrícula</td><td class="num">2004–2025</td><td class="num" style="color:#2563eb">75<span class="bar" style="width:0.31rem"></span></td><td><span class="badge-soft info">censo</span></td></tr>
<tr><td><div class="src"><span class="chip" style="background:#7c3aed"></span><span><b>CPV</b><small>Censos Nacionales 2017</small></span></div></td><td class="hide-sm">Población y vivienda</td><td class="num">2017</td><td class="num" style="color:#7c3aed">5<span class="bar" style="width:0.25rem"></span></td><td><span class="badge-soft info">censo</span></td></tr>
</tbody></table></div>

Años, módulos y formatos de cada una, en [Las diez fuentes, en cifras](articles/fuentes.html).
