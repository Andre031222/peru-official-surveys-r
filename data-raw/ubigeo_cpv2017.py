"""Builds inst/ubigeo/ubigeo_cpv2017.csv and inst/ubigeo/crosswalk_cpv2017.csv,
and aligns ubigeo_distritos.csv (from ubigeo.py) with the 2017 census frame.

Sources:
  1. Districts of the 2017 census: departam.csv, provinci.csv and distrito.csv inside
     PER2017.zip, the full CPV 2017 converted from REDATAM by redatam-microdata
     (CC BY 4.0): https://github.com/pachadotdev/redatam-microdata/releases/download/2.0.2/PER2017.zip
     Only the codes are used; the names there have broken accents.
  2. Padron de Servicios Educativos 2025 (MINEDU, ESCALE):
     https://escale.minedu.gob.pe/documents/inicio/Bases%20de%20datos/A.%20Censo%20Educativo/2025/00_Padron.zip
     Only CODGEO, CODCP_INEI and the place names are read. The file also holds names, phones
     and e-mails of school heads: it is never copied anywhere.

Method for the crosswalk: a school in a district created after 2017 keeps the INEI code of its
populated centre (CODCP_INEI, 10 digits), whose first 6 digits are the 2017 district. Each new
district is linked to the 2017 districts that hold its schools. Not yet checked against each
creation law.

Needs dbfread. Run it from a scratch folder after ubigeo.py, with PER2017.zip next to it.
"""
import csv, collections, os, subprocess, urllib.request, zipfile, io
from dbfread import DBF

PADRON = "https://escale.minedu.gob.pe/documents/inicio/Bases%20de%20datos/A.%20Censo%20Educativo/2025/00_Padron.zip"
if not os.path.exists("Padron.dbf"):
    urllib.request.urlretrieve(PADRON, "00_Padron.zip")
    subprocess.run(["unzip", "-q", "-o", "00_Padron.zip", "Padron.dbf"], check=True)

z = zipfile.ZipFile("PER2017.zip")
def rows(name):
    return list(csv.DictReader(io.TextIOWrapper(z.open(name), encoding="latin-1"), delimiter=";"))
dep = {r["departam_ref_id"]: r["ccdd"] for r in rows("departam.csv")}
prov = {r["provinci_ref_id"]: dep[r["departam_ref_id"]] + r["ccpp"] for r in rows("provinci.csv")}
cpv = sorted(prov[r["provinci_ref_id"]] + r["ccdi"] for r in rows("distrito.csv"))
assert len(cpv) == len(set(cpv)) == 1874

names, parents = {}, collections.defaultdict(collections.Counter)
for r in DBF("Padron.dbf", encoding="cp1252", load=False,
             ignore_missing_memofile=True, char_decode_errors="replace"):
    g = (r["CODGEO"] or "").strip()
    if len(g) != 6:
        continue
    names.setdefault(g, (r["D_DPTO"].strip(), r["D_PROV"].strip(), r["D_DIST"].strip()))
    cp = (r["CODCP_INEI"] or "").strip()
    if g not in cpv and len(cp) == 10:
        parents[g][cp[:6]] += 1

with open("ubigeo_cpv2017.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["ubigeo", "departamento", "provincia", "distrito"])
    for u in cpv:
        w.writerow([u, *names[u]])

with open("crosswalk_cpv2017.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["ubigeo", "distrito", "ubigeo_cpv2017", "distrito_cpv2017", "n_iiee",
                "multi_padre", "metodo", "verificado_con_ley"])
    for g in sorted(parents):
        c = parents[g]
        # Two schools of Boqueron carry a code from Huanuco, another department: a register error.
        keep = [(p, n) for p, n in c.most_common() if p in cpv and p[:2] == g[:2]]
        for p, n in keep:
            w.writerow([g, names[g][2], p, names[p][2], n, "si" if len(keep) > 1 else "no",
                        "prefijo de CODCP_INEI en el Padron MINEDU 2025", "no"])
        print(g, names[g][2], c.most_common())

# Align the yearly list with the census frame: a district in the 2017 census existed in 2017,
# even if RENAMU lists it later. Districts in the 2025 Padron and not in RENAMU 2025 are added.
small = {"De", "Del", "La", "Las", "Los", "Y", "El"}
def tt(x):
    w = x.strip().title().split(" ")
    return " ".join([w[0]] + [v.lower() if v in small else v for v in w[1:]])

with open("ubigeo_distritos.csv", encoding="utf-8") as f:
    d = list(csv.DictReader(f))
fields = list(d[0])
for r in d:
    if r["ubigeo"] in cpv and not r["hasta"] and int(r["desde"]) > 2017:
        r["desde"], r["desde_fuente"] = "2017", "CPV 2017"
current = {r["ubigeo"] for r in d if not r["hasta"]}
for g in sorted(set(names) - current):
    dep, prov, dist = names[g]
    d.append(dict(ubigeo=g, distrito=tt(dist), provincia=tt(prov), departamento=tt(dep), desde="2025",
                  hasta="", desde_fuente="Padron MINEDU 2025", primer_anio_renamu="", ley="", fecha_ley=""))
d.sort(key=lambda r: (r["ubigeo"], int(r["desde"])))
with open("ubigeo_distritos.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(d)
print(sum(1 for r in d if int(r["desde"]) <= 2017 and (not r["hasta"] or int(r["hasta"]) >= 2017)), "districts in 2017")
