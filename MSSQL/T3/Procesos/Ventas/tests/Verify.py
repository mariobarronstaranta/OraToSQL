"""QA de los CSV ficticios generados por RunLocal.bat; no requiere Oracle."""
from pathlib import Path
import csv
from decimal import Decimal

root=Path(__file__).resolve().parent/'work'
for folder,tag,count,fields,negative_fx in [
 ('VentaAdrianG - CFDI','A',5,20,True),
 ('VentaFelipeG','F',4,5,False),
 ('VentaFelipeG - CFDI','G',5,23,False),
]:
 files=sorted((root/folder).glob('*.CSV'),key=lambda p:p.stat().st_mtime)
 assert files,folder
 file=files[-1]
 with file.open(encoding='utf-8-sig',newline='') as f:
  reader=csv.DictReader(f); rows=list(reader)
  assert len(reader.fieldnames)==fields
 assert len(rows)==count,(folder,len(rows))
 assert all(None not in r for r in rows),'CSV desplazado'
 assert file.read_bytes()==(file.parent/'Processed'/file.name).read_bytes()
 assert not (file.parent/'.venta_lock').exists()
 byid={}
 for row in rows: byid.setdefault(row['FACTURA'],[]).append(row)
 assert tag+'C' not in byid and tag+'E' not in byid,'Cancelado o limite final incluido'
 if fields==5:
  assert tag+'X' not in byid and tag+'F' not in byid
  assert tag+'D' in byid and tag+'N' in byid
  assert Decimal(byid[tag+'R'][0]['TOTAL'])==Decimal('129.92')
 else:
  assert tag+'D' not in byid and tag+'N' not in byid and tag+'F' in byid
  assert len(byid[tag+'S'])==2,'Multiplicidad de VOIDDOC no conservada'
  sale=byid[tag+'S'][0]
  assert sale['NOMBRE']=='Compañía  "QA"'
  assert sale['FOLIO_FISCAL']=='UUID,"QA"\r\nline2'
  assert sale['DOC_FACTURA']=="'"+tag+'S'
  assert Decimal(sale['INCOBRABLE_NC'])==40,'Incobrable historico omitido'
  assert Decimal(byid[tag+'R'][0]['TOTAL'])==Decimal('-129.92')
  assert Decimal(byid[tag+'X'][0]['TOTAL'])==Decimal('-129.92' if negative_fx else '129.92')
  if fields==23:
   credit=byid[tag+'R'][0]
   assert Decimal(credit['BONIF_SUBT'])==5 and Decimal(credit['BONIF_IVA'])==Decimal('.8')
   assert sale['FECHA_DOCUMENTO']=='03/07/2026 00:00:00'
 print(f'OK {folder}: {count} registros, {fields} columnas; reglas y copia historica verificadas')
