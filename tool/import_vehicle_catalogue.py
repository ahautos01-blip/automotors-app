"""Refresh bundled public reference data; never called by the app at runtime.

NHTSA/vPIC is a US-market registry, not a claim of worldwide completeness.
European/historic and marine references are maintained separately in the seed.
Requests are cached, bounded and retried once; incomplete imports are reported.
"""
import concurrent.futures, json, time, urllib.request, urllib.parse, unicodedata
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'tool/catalog-cache'
CACHE.mkdir(exist_ok=True)
BASE='https://vpic.nhtsa.dot.gov/api/vehicles/'
TYPES={'car':['car','multipurpose'],'motorcycle':['motorcycle'],'truck':['truck']}
ALIASES={'MERCEDES-BENZ':'Mercedes-Benz','MERCEDES BENZ':'Mercedes-Benz','BMW':'BMW','BMW MOTORRAD':'BMW','VW':'Volkswagen','VOLKSWAGEN':'Volkswagen','HARLEY DAVIDSON':'Harley-Davidson','HARLEY-DAVIDSON':'Harley-Davidson','BENETEAU':'Beneteau','BÉNÉTEAU':'Beneteau','MOTO GUZZI':'Moto Guzzi','ROYAL ENFIELD':'Royal Enfield','KTM':'KTM','CFMOTO':'CFMoto','KYMCO':'Kymco','SYM':'SYM','NIU':'NIU','MG':'MG','MINI':'MINI','DS':'DS Automobiles','DS AUTOMOBILES':'DS Automobiles','SKODA':'Škoda','CITROEN':'Citroën','SEAT':'SEAT','GMC':'GMC','BYD':'BYD','GAS GAS':'GasGas','GASGAS':'GasGas'}
def key(s):return ''.join(c for c in unicodedata.normalize('NFKD',s.casefold()) if not unicodedata.combining(c)).replace('-','').replace(' ','')
def display(s):
 s=s.strip()
 return ALIASES.get(s.upper(),s.title() if s.isupper() else s)
def fetch(endpoint,cache):
 if cache.exists():return json.loads(cache.read_text(encoding='utf-8'))
 for attempt in range(2):
  try:
   req=urllib.request.Request(BASE+endpoint,headers={'User-Agent':'AUTOMOTORS-catalogue-refresh/1.0'})
   with urllib.request.urlopen(req,timeout=45) as response: data=json.load(response)
   if not isinstance(data.get('Results'),list):raise ValueError('Invalid reference response')
   cache.write_text(json.dumps(data,ensure_ascii=False),encoding='utf-8');return data
  except Exception:
   if attempt:raise
   time.sleep(3)

def main():
 seed=json.loads((ROOT/'assets/vehicle_catalogue_seed.json').read_text(encoding='utf-8'))
 catalogue={c:{b:set(ms) for b,ms in data.items()} for c,data in seed.items()}
 jobs=[];errors=[]
 for category,types in TYPES.items():
  for kind in types:
   try:
    makes=fetch('GetMakesForVehicleType/'+kind+'?format=json',CACHE/(kind+'.json'))['Results']
    for make in makes:
     brand=display(make['MakeName']); mid=int(make['MakeId'])
     canonical=next((b for b in catalogue[category] if key(b)==key(brand)),brand)
     catalogue[category].setdefault(canonical,set());jobs.append((category,kind,mid,canonical))
   except Exception as error:errors.append({'type':kind,'error':str(error)})
  print(category,'makes',len(catalogue[category]),flush=True)
 def model_job(job):
  category,kind,mid,brand=job
  endpoint=f'GetModelsForMakeIdYear/makeId/{mid}/vehicletype/{kind}?format=json'
  try:
   cached=(CACHE/f'{kind}-{mid}.json').exists()
   cached=CACHE/f'{kind}-{mid}.json'
   was_cached=cached.exists()
   data=fetch(endpoint,cached)
   names={r['Model_Name'].strip() for r in data['Results'] if int(r.get('Make_ID',mid))==mid and isinstance(r.get('Model_Name'),str) and 0<len(r['Model_Name'].strip())<=100}
   if not cached:time.sleep(.25)
   return category,brand,names,None
  except Exception as error:return category,brand,set(),str(error)
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  for index,(category,brand,names,error) in enumerate(pool.map(model_job,jobs),1):
   catalogue[category][brand].update(names)
   if error:errors.append({'category':category,'brand':brand,'error':error})
   if index%25==0:print('Imported',index,'/',len(jobs),flush=True)
 result={c:{b:sorted(ms,key=key) for b,ms in sorted(data.items(),key=lambda x:key(x[0]))} for c,data in catalogue.items()}
 (ROOT/'assets/vehicle_catalogue.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
 report={'sources':['https://vpic.nhtsa.dot.gov/api/','assets/vehicle_catalogue_seed.json'],'coverage':'Reference suggestions, not exhaustive worldwide coverage','counts':{c:{'brands':len(d),'models':sum(len(m) for m in d.values())} for c,d in result.items()},'failed_requests':errors}
 (ROOT/'tool/catalog-cache/import-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(report['counts']),flush=True);print('Failed requests:',len(errors),flush=True)

if __name__=='__main__':main()
