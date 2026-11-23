"""Builds inst/ubigeo/ubigeo_distritos.csv and inst/ubigeo/ubigeo_cambios.csv.

Sources, both from INEI:
  1. RENAMU 2004-2025, module "Datos Generales de la Municipalidad", from
     https://proyectos.inei.gob.pe/microdatos/ (one district per row, with CCDD, CCPP, CCDI).
  2. Directorio Nacional de Gobiernos Regionales, Municipalidades Provinciales, Distritales y de
     Centros Poblados 2025 (PDF), for the law that created each district:
     https://cdn.www.gob.pe/uploads/document/file/7999763/6722617-directorio-nacional-de-gobiernos-regionales-municipalidades-provinciales-distritales-y-de-centros-poblados-2025.pdf

Run it from a scratch folder outside the package. It needs pyreadstat and pdftotext.
"""
import subprocess, os, urllib.request

MODULES = {
    2004: "144-Modulo86", 2005: "177-Modulo86", 2006: "185-Modulo86", 2007: "207-Modulo86",
    2008: "225-Modulo86", 2009: "249-Modulo86", 2010: "269-Modulo86", 2011: "304-Modulo86",
    2012: "328-Modulo86", 2013: "388-Modulo86", 2014: "430-Modulo86", 2015: "499-Modulo727",
    2016: "538-Modulo727", 2017: "594-Modulo727", 2018: "624-Modulo1341", 2019: "656-Modulo1482",
    2020: "730-Modulo1587", 2021: "756-Modulo1658", 2022: "783-Modulo1726", 2023: "902-Modulo1814",
    2024: "928-Modulo1814", 2025: "984-Modulo1963",
}
PDF = "https://cdn.www.gob.pe/uploads/document/file/7999763/6722617-directorio-nacional-de-gobiernos-regionales-municipalidades-provinciales-distritales-y-de-centros-poblados-2025.pdf"

for y, m in MODULES.items():
    os.makedirs(str(y), exist_ok=True)
    z = f"{y}/{m}.zip"
    if not os.path.exists(z):
        urllib.request.urlretrieve(f"https://proyectos.inei.gob.pe/iinei/srienaho/descarga/SPSS/{m}.zip", z)
        subprocess.run(["unzip", "-q", "-o", z, "-d", str(y)], check=True)
if not os.path.exists("dir2025.txt"):
    urllib.request.urlretrieve(PDF, "dir2025.pdf")
    subprocess.run(["pdftotext", "-layout", "dir2025.pdf", "dir2025.txt"], check=True)

# The file holding the district list changes name almost every year.

# --- step 1: districts per year (RENAMU) ---
import pyreadstat, unicodedata, csv, re, json
files = {
2004:'2004/CUADRO_C0001.sav',2005:'2005/cuadro_c0001.sav',2006:'2006/C0001.sav',
2007:'2007/207-Modulo86/C001.sav',2008:'2008/225-Modulo86/225-Modulo86/C001.sav',
2009:'2009/249-Modulo86/XX-Modulo86/C001.sav',2010:'2010/269-Modulo86/C001.sav',
2011:'2011/304-Modulo86/XX-Modulo86/C001.sav',2012:'2012/328-Modulo86/C001.sav',
2013:'2013/388-Modulo86/C001.sav',2014:'2014/430-Modulo86/C001.sav',2015:'2015/499-Modulo727/CDIR.sav',
2016:'2016/538-Modulo727/CDIR.sav',2017:'2017/594-Modulo727/CDIR.sav',2018:'2018/624-Modulo1341/Directorio.sav',
2019:'2019/1. Datos Generales de la Municipalidad/CDIR.sav',2020:'2020/730-Modulo1587/CDIR.sav',
2021:'2021/Base_Renamu_2021_f.sav',2022:'2022/Base_RENAMU_2022_f.sav',2023:'2023/Base-Datos_2023_f.sav',
2024:'2024/Base-Datos_2024_f.sav',2025:'2025/984-Modulo1963/Base-Datos_2025_f_.sav'}
def norm(s):
    s=unicodedata.normalize('NFKD',str(s)).encode('ascii','ignore').decode().upper()
    return re.sub(r'\s+',' ',s).strip()
data={}
for y,f in files.items():
    cols=pyreadstat.read_sav(f,metadataonly=True)[1].column_names
    low={c.lower():c for c in cols}
    nd=[low[k] for k in ('nom_dist','dist_nombre','distrito') if k in low][0]
    np_=[low[k] for k in ('nom_prov','prov_nombre','provincia') if k in low][0]
    ndp=[low[k] for k in ('nom_dpto','dpto_nombre','departamento') if k in low][0]
    df,_=pyreadstat.read_sav(f,usecols=[low['ccdd'],low['ccpp'],low['ccdi'],nd,np_,ndp], encoding=None)
    d={}
    skipped=0
    for _,r in df.iterrows():
        if not str(r[low['ccdd']]).strip() or not str(r[low['ccdi']]).strip():
            skipped+=1; continue
        u=f"{int(float(r[low['ccdd']])):02d}{int(float(r[low['ccpp']])):02d}{int(float(r[low['ccdi']])):02d}"
        d[u]=(str(r[nd]).strip(),str(r[np_]).strip(),str(r[ndp]).strip())
    data[y]=d
    print(y,len(df),len(d),'vacias',skipped)
json.dump({y:{u:list(v) for u,v in d.items()} for y,d in data.items()},open('renamu_ubigeos.json','w'),ensure_ascii=False)

# --- step 2: creation laws (Directorio 2025) ---

L=open('dir2025.txt',encoding='utf-8').read().split('\n')
code_re=re.compile(r'^\s{20,}((?:0[1-9]|1[0-9]|2[0-5])\d{4})\s{2,}(\S.*)$')
out={}
for i,l in enumerate(L):
    m=code_re.match(l)
    if not m: continue
    u=m.group(1)
    if u in out: continue
    win=L[max(0,i-3):i+3]
    law=None; date=None
    for w in L[max(0,i-3):i+1][::-1]:
        mm=re.search(r'((?:Ley|D\.?\s?L\.?|Decreto Ley|D\.\s?Ley|Decreto Legislativo|Resoluci\S+ Legislativa|D\.?S\.?|Ley Regional)\s*N[°º]\s*[\d\-A-Z]+)\s+del', w)
        if mm: law=re.sub(r'\s+',' ',mm.group(1)); break
    for w in L[i:i+3]:
        dd=re.search(r'\b(\d{1,2} (?:Ene|Feb|Mar|Abr|May|Jun|Jul|Ago|Set|Sep|Oct|Nov|Dic) \d{4})\b', w)
        if dd: date=dd.group(1); break
    epoca='Época Indep.' in l or 'poca Indep' in l
    out[u]=dict(ley=law if not epoca else 'Epoca de la Independencia', fecha=date if not epoca else None)
print(len(out), sum(1 for v in out.values() if v['ley']), sum(1 for v in out.values() if v['fecha']))
json.dump(out,open('laws2025.json','w'),ensure_ascii=False,indent=0)
for u in ['030609','130112','160801','160405','010206','010201','070107','160701','211105']:
    print(u,out.get(u))

# --- step 3: tables ---

D={int(k):v for k,v in json.load(open('renamu_ubigeos.json')).items()}
LW=json.load(open('laws2025.json'))
ys=sorted(D)
def n(s): return re.sub(r'\s+',' ',unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().upper()).strip()
months=dict(Ene=1,Feb=2,Mar=3,Abr=4,May=5,Jun=6,Jul=7,Ago=8,Set=9,Sep=9,Oct=10,Nov=11,Dic=12)

# periods per code and name: split when the name changes in a way that is not just spelling
segs=[]
for u in sorted(set().union(*[set(D[y]) for y in ys])):
    pres=[y for y in ys if u in D[y]]
    cur=None
    for y in pres:
        nm=n(D[y][u][0])
        if cur and (cur['key']==nm or (nm not in ('LA PECA','BAGUA') or cur['key'] not in ('LA PECA','BAGUA'))):
            cur['hasta']=y; cur['row']=D[y][u]
            continue
        cur=dict(ubigeo=u,key=nm,desde=y,hasta=y,row=D[y][u]); segs.append(cur)

# recodes: same name, same department, old code leaves and new code enters in the same transition
changes=[]
for a,b in zip(ys,ys[1:]):
    gone={u:n(D[a][u][0]) for u in set(D[a])-set(D[b])}
    new={u:n(D[b][u][0]) for u in set(D[b])-set(D[a])}
    renamed={u:n(D[b][u][0]) for u in set(D[a])&set(D[b]) if {n(D[a][u][0]),n(D[b][u][0])}=={'LA PECA','BAGUA'}}
    for u,nm in list(gone.items())+[(u,n(D[a][u][0])) for u in renamed]:
        cand=[v for v,nv in list(new.items())+list(renamed.items()) if nv==nm and v[:2]==u[:2] and v!=u]
        if len(cand)==1:
            if u in renamed:
                txt=f'Mismo nombre y departamento: en RENAMU {a} el codigo {u} es {D[a][u][0].title()}; en {b} ese nombre figura con {cand[0]} y {u} pasa a otro distrito'
            elif cand[0] in renamed:
                txt=f'Mismo nombre y departamento: {u} figura en RENAMU {a} y deja de figurar en {b}; desde {b} ese nombre lo lleva {cand[0]}'
            else:
                txt=f'Mismo nombre y departamento: {u} figura en RENAMU {a} y deja de figurar en {b}; {cand[0]} aparece en {b}'
            changes.append(dict(anio=b,de=u,a=cand[0],nombre=D[b][cand[0]][0].title(),tipo='recodificacion',metodo=txt))
    changes.sort(key=lambda c:(c['anio'],c['de']))
for c in changes: print(c['anio'],c['de'],'->',c['a'],c['nombre'])
recoded_new={c['a'] for c in changes}

succ={c['de']:c['a'] for c in changes}
small={'De','Del','La','Las','Los','Y','El'}
def tt(x):
    w=x.strip().title().split(' ')
    return ' '.join([w[0]]+[v.lower() if v in small else v for v in w[1:]])
rows=[]
for s in segs:
    u=s['ubigeo']; dist,prov,dep=s['row']
    law=LW.get(u) or LW.get(succ.get(u,''),{}) if (s['hasta']!=ys[-1]) else (LW.get(u) or {})
    law=law or {}
    desde=s['desde']; fuente_desde='RENAMU'
    is_last = s['hasta']==ys[-1]
    if s['desde']>ys[0] and u not in recoded_new and law.get('fecha') and law.get('ley')!='Epoca de la Independencia':
        y=int(law['fecha'][-4:])
        if y < s['desde']:
            desde=y; fuente_desde='ley de creacion'
    rows.append(dict(ubigeo=u, distrito=tt(dist), provincia=tt(prov), departamento=tt(dep),
        desde=desde, hasta=(s['hasta'] if not is_last else ''), desde_fuente=fuente_desde,
        primer_anio_renamu=s['desde'], ley=(law.get('ley') or '') if is_last else '', fecha_ley=(law.get('fecha') or '') if is_last else ''))
print(len(rows), sum(1 for r in rows if not r['hasta']))
with open('ubigeo_distritos.csv','w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
# A new province can also receive districts created at the same time (Andoas in Datem del
# Maranon, Rosa Panduro and Yaguas in Putumayo). The sources do not say which recoded district
# gave up territory, so every recoding in that province is flagged and none is guessed.
targets={c['a'] for c in changes}
for c in changes:
    new=[r['ubigeo'] for r in rows if r['ubigeo'][:4]==c['a'][:4] and r['ubigeo'] not in targets
         and not r['hasta'] and c['anio']-1 <= r['desde'] <= c['anio']]
    c['nuevos_en_provincia']=';'.join(sorted(new))
with open('ubigeo_cambios.csv','w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=['anio','de','a','nombre','tipo','nuevos_en_provincia','metodo']); w.writeheader(); w.writerows(changes)
