# Tablas de ubigeo / Ubigeo tables

Dos tablas que usan `fa_ubigeo()` y `fa_districts()`. Se generan con `data-raw/ubigeo.py`.

## Fuentes

1. **RENAMU 2004-2025** (INEI, Registro Nacional de Municipalidades), modulo "Datos Generales de
   la Municipalidad", en <https://proyectos.inei.gob.pe/microdatos/>. Cada año trae una fila por
   municipalidad con `CCDD`, `CCPP` y `CCDI`. Es la lista oficial de distritos de cada año.
2. **Directorio Nacional de Gobiernos Regionales, Municipalidades Provinciales, Distritales y de
   Centros Poblados 2025** (INEI, PDF), para la ley y la fecha de creación de cada distrito:
   <https://cdn.www.gob.pe/uploads/document/file/7999763/6722617-directorio-nacional-de-gobiernos-regionales-municipalidades-provinciales-distritales-y-de-centros-poblados-2025.pdf>

## `ubigeo_distritos.csv`

Un distrito por fila y por periodo de validez de su código (1900 filas, 1891 vigentes en 2025).

| Columna | Contenido |
|---|---|
| `ubigeo` | Código de 6 dígitos |
| `distrito`, `provincia`, `departamento` | Nombres según RENAMU, sin tildes |
| `desde`, `hasta` | Años en que el código vale para ese distrito; `hasta` vacío si sigue vigente |
| `desde_fuente` | `RENAMU` (primer año en RENAMU) o `ley de creacion` (año de la ley, si es anterior) |
| `primer_anio_renamu` | Primer año en que aparece en RENAMU |
| `ley`, `fecha_ley` | Ley de creación según el Directorio 2025, cuando el PDF la trae |

Un mismo código puede tener dos filas: `010201` es La Peca hasta 2006 y Bagua desde 2007.

## `ubigeo_cambios.csv`

Los nueve cambios de código de un mismo distrito entre 2004 y 2025.

| Año | De | A | Distrito | Motivo |
|---|---|---|---|---|
| 2006 | 160203, 160204, 160207, 160208, 160209 | 160701 a 160705 | Barranca, Cahuapanas, Manseriche, Morona, Pastaza | Nueva provincia Datem del Marañón |
| 2007 | 010201 / 010299 | 010206 / 010201 | La Peca / Bagua | Intercambio de códigos |
| 2015 | 160109, 160114 | 160801, 160803 | Putumayo, Teniente Manuel Clavero | Nueva provincia Putumayo |

**Método.** Un cambio se registra solo cuando un código deja de figurar en RENAMU un año y aparece
otro con el mismo nombre, en el mismo departamento, ese mismo año. No se infiere nada más.

## Límites

- **Distritos creados.** 61 distritos se crearon por división de otros entre 2005 y 2025. Ni
  RENAMU ni el Directorio dicen de qué distrito salió cada uno, así que no se asigna distrito de
  origen: al llevarlos a un año anterior quedan `NA` con estado `created_after_base`.
- **RENAMU va detrás de la ley.** Un distrito creado por ley puede tardar uno o dos años en
  aparecer. Por eso `desde` toma el año de la ley cuando es anterior.
- **Faltantes conocidos.** Santa Rosa de Loreto (Ley 32403, julio de 2025) aún no figura en RENAMU
  2025 ni en esta tabla.
- **Fuera de 2004-2025** `fa_ubigeo()` usa el año más cercano y avisa.
