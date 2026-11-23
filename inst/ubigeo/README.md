# Tablas de ubigeo / Ubigeo tables

Las tablas que usan `fa_ubigeo()` y `fa_districts()`. Se generan con `data-raw/ubigeo.py` y luego
`data-raw/ubigeo_cpv2017.py`. Todos los códigos son del INEI, como texto de 6 dígitos.

## Fuentes

1. **RENAMU 2004-2025** (INEI, Registro Nacional de Municipalidades), módulo "Datos Generales de
   la Municipalidad", en <https://proyectos.inei.gob.pe/microdatos/>. Una fila por municipalidad
   con `CCDD`, `CCPP` y `CCDI`: la lista oficial de distritos de cada año.
2. **Directorio Nacional de Gobiernos Regionales, Municipalidades Provinciales, Distritales y de
   Centros Poblados 2025** (INEI, PDF), para la ley y la fecha de creación de cada distrito:
   <https://cdn.www.gob.pe/uploads/document/file/7999763/6722617-directorio-nacional-de-gobiernos-regionales-municipalidades-provinciales-distritales-y-de-centros-poblados-2025.pdf>
3. **Censos Nacionales 2017**, lista de los 1874 distritos del marco censal, tomada de los códigos
   de `departam.csv`, `provinci.csv` y `distrito.csv` en `PER2017.zip` de
   [redatam-microdata](https://github.com/pachadotdev/redatam-microdata) (CC BY 4.0), una
   conversión del CPV 2017 en REDATAM. Solo se usan los códigos.
4. **Padrón de Servicios Educativos 2025** (MINEDU, ESCALE),
   <https://escale.minedu.gob.pe/documents/inicio/Bases%20de%20datos/A.%20Censo%20Educativo/2025/00_Padron.zip>.
   Solo se leen `CODGEO`, `CODCP_INEI` y los nombres de lugar. El padrón trae datos personales de
   los directores: no se copia ni se redistribuye nada de él.

## Archivos

| Archivo | Contenido |
|---|---|
| `ubigeo_distritos.csv` | Un distrito por fila y por periodo de validez de su código: `ubigeo`, nombres, `desde`, `hasta` (vacío si sigue vigente), `desde_fuente`, primer año en RENAMU, ley y fecha. 1901 filas, 1892 vigentes |
| `ubigeo_cambios.csv` | Los 9 cambios de código de un mismo distrito entre 2004 y 2025, con los distritos creados a la vez en la nueva provincia |
| `ubigeo_cpv2017.csv` | Los 1874 distritos del Censo 2017, base de armonización |
| `crosswalk_cpv2017.csv` | Los 18 distritos creados después de 2017 y su distrito de 2017 (21 filas) |
| `ubigeo_legados_enaho.csv` | Los 4 códigos de la ENAHO 2004-2025 que no están en el marco 2017 y qué hace faperu con ellos |

### `desde`

Es el primer año en RENAMU, salvo en dos casos, porque RENAMU registra un distrito uno o dos años
después de su ley: si el Directorio 2025 trae la fecha de la ley y es anterior, vale el año de la
ley (`ley de creacion`); si el distrito está en el Censo 2017, vale como máximo 2017 (`CPV 2017`).
Santa Rosa de Loreto (160405) no está en RENAMU 2025 y se agrega desde el Padrón 2025
(`Padron MINEDU 2025`). Con eso, `fa_districts(2017)` da los 1874 distritos del censo y
`fa_districts(2025)` da 1892.

### Cambios de código

| Año | De | A | Distrito | Motivo |
|---|---|---|---|---|
| 2006 | 160203, 160204, 160207, 160208, 160209 | 160701 a 160705 | Barranca, Cahuapanas, Manseriche, Morona, Pastaza | Nueva provincia Datem del Marañón, donde también se crea Andoas (160706) |
| 2007 | 010201 / 010299 | 010206 / 010201 | La Peca / Bagua | Intercambio de códigos |
| 2015 | 160109, 160114 | 160801, 160803 | Putumayo, Teniente Manuel Clavero | Nueva provincia Putumayo, donde también se crean Rosa Panduro (160802) y Yaguas (160804) |

**Método.** Un cambio se registra solo cuando un código deja de figurar en RENAMU un año y aparece
otro con el mismo nombre, en el mismo departamento, ese mismo año. Si en la nueva provincia se
crearon otros distritos esos años, el cambio queda marcado (`nuevos_en_provincia`) y
`fa_ubigeo()` lo informa como `recoded_partial`: el distrito viejo pudo ser más grande, y las
fuentes no dicen cuál cedió territorio.

### Distritos creados después de 2017

Cada distrito nuevo se une al distrito de 2017 donde están sus colegios: el `CODCP_INEI` de 10
dígitos de cada colegio conserva el código del centro poblado de 2017, y sus 6 primeros dígitos son
el distrito de 2017. `n_iiee` es cuántos colegios lo respaldan.

- **Por verificar contra la ley.** Ninguna fila se ha contrastado todavía con su ley de creación
  (`verificado_con_ley = no`).
- **Dos padres.** Lambras (090724: Huachocolpa y Surcubamba) y Santa Lucía (221006: Uchiza y
  Tocache) salen de dos distritos (`multi_padre = si`). `fa_ubigeo()` no los reparte: quedan `NA`
  con estado `multi_parent`.
- **Boquerón** (250307) tiene 30 colegios con prefijo de Padre Abad y 2 con uno de Huánuco
  (100603), otro departamento. Se tratan como error del padrón y no entran.

## Límites

- **Distritos creados entre 2005 y 2017.** 44 distritos se crearon en esos años y ni RENAMU ni el
  Directorio dicen de cuál salieron. No se asigna padre: al llevarlos a un año anterior quedan `NA`
  con estado `created_after_base`.
- **Códigos viejos en las encuestas.** La ENAHO siguió usando 160203 y 160207 en 2006 y usó
  120699, que no es un distrito, en 2013-2020. Ver `ubigeo_legados_enaho.csv`.
- **Las encuestas usan el marco 2017.** Probado con las Sumarias de la ENAHO 2004-2025: fuera de
  los 4 códigos viejos, todos los códigos están en la lista del año. Desde 2018 la ENAHO usa los
  1874 distritos del censo, así que un código marcado `area_changed` en la ENAHO 2021-2025 (por
  ejemplo El Porvenir, 130102) sigue refiriéndose al territorio de 2017.
- **INEI no es RENIEC.** Desde el departamento 07 la numeración cambia: el INEI pone al Callao en
  07 y RENIEC en 24 (Cusco es 080101 en el INEI y 070101 en RENIEC). Estas tablas son solo INEI.
- **Fuera de 2004-2025** `fa_ubigeo()` usa el año más cercano y avisa.
