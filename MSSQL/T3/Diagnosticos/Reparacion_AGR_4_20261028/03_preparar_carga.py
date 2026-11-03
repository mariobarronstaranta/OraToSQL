"""Valida los JSON de Oracle y genera 03_MSSQL_CARGAR_ORIGEN.sql.
Uso: python 03_preparar_carga.py --entrada carpeta_json
No conecta a ninguna base. Rechaza exports ambiguos/incompletos.
"""
import argparse, datetime, decimal, hashlib, json
from pathlib import Path

HERE=Path(__file__).resolve().parent
S='REPAIR_AGR_20261028'
MAP={
 '262201997234':('V0225-134949',529120,'0050497582','8138.65'),
 '262201997964':('V0822-105802',529096,'0050486340','2247.90'),
 '262201997720':('V0179-67553',529050,'0056049466','2562.27'),
 '262201997198':('V0440-70133',529179,'0050484446','5454.50'),
}
OLD={514957:'262201490494',514969:'262201491972',514981:'262000077835',514984:'262201489175'}
D=decimal.Decimal

def need(ok,msg):
    if not ok: raise ValueError(msg)

def literal(v,t,size):
    if v is None: return 'NULL'
    if t=='datetime2':
        need(isinstance(v,str),'Fecha no textual')
        parsed=datetime.datetime.strptime(v,'%Y-%m-%dT%H:%M:%S')
        need(parsed.strftime('%Y-%m-%dT%H:%M:%S')==v,'Formato de fecha no canonico')
        return "CONVERT(datetime2(0),'"+v+"',126)"
    if t in ('varchar','char'):
        need(isinstance(v,str),'Texto no textual')
        need(v!='','Oracle debe exportar vacios como null')
        maxlen=int(size[1:-1]); need(len(v.encode('cp1252'))<=maxlen,'Texto excede '+size)
        need('\x00' not in v,'NUL no admitido')
        return "N'"+v.replace("'","''")+"'"
    if t=='decimal':
        need(not isinstance(v,(bool,str)),'Numero debe ser JSON numerico')
        n=D(v); p,scale=map(int,size[1:-1].split(','))
        need(n.is_finite() and abs(n)<D(10)**(p-scale),'Numero fuera de rango')
        need(n==n.quantize(D(1).scaleb(-scale)),'Decimales exceden escala')
        return format(n,'f')
    raise ValueError('Tipo no soportado '+t)

def generate(folder,output):
    schema=json.loads((HERE/'schema.json').read_text(encoding='utf-8'))
    data={}; digest=hashlib.sha256()
    for table,m in schema.items():
        raw=(folder/(table+'.json')).read_bytes(); digest.update(table.encode()+b'\0'+raw)
        rows=json.loads(raw.decode('utf-8-sig'),parse_float=D)
        need(isinstance(rows,list),table+': se esperaba array JSON')
        cols={x[0] for x in m['columns']}
        for row in rows:
            need(isinstance(row,dict) and set(row)==cols,table+': columnas distintas del DDL esperado')
            for c,t,size in m['columns']: literal(row[c],t,size)
        data[table]=rows
    raw=(folder/'metadata.json').read_bytes(); digest.update(raw)
    meta=json.loads(raw.decode('utf-8-sig'),parse_float=D)
    need(set(meta)=={'MAX_CONTROL','MAX_DETALLE','CAPTURA'},'Metadata incompleta')
    literal(meta['CAPTURA'],'datetime2','(0)')
    need(all(isinstance(meta[k],(int,D)) and D(meta[k])==int(meta[k]) and int(meta[k])>=534442
             for k in ('MAX_CONTROL','MAX_DETALLE')),'Maximos origen inesperados')
    cob=data['CFDI_COBRANZA']; ctrl=data['CFDI_AGRUPACION_CTRL']; det=data['CFDI_AGRUPACION_PAGO']
    need(len(cob)==4 and {r['ASIGNACION_ID'] for r in cob}==set(MAP),'Cobranza: deben ser exactamente cuatro IDs')
    for r in cob:
        factura,g,cliente,importe=MAP[r['ASIGNACION_ID']]
        need(r['FACTURA']==factura and r['NOTA_VENTA']==factura and r['CLIENTE_SAP']==cliente,'Relacion cobranza distinta de Oracle revisado')
        need(D(r['IMPORTE'])==D(importe)==D(r['SALDO_ANTERIOR']),'Importes distintos de los revisados')
        need(r['STATUS'] is None and r['ACCNT_ID'] is None and r['UUID_VENTA'] and len(r['UUID_VENTA'])==36,'Estado/UUID inesperado')
        need(r['FECHA_ENVIO'] and r['FECHA_ENVIO'].startswith('2026-10-02T'),'Fecha envio distinta del corte revisado')
    expected=set(OLD)|{x[1] for x in MAP.values()}
    need(len(ctrl)==8 and {int(r['AGRUPACION']) for r in ctrl}==expected,'Deben ser ocho controles unicos')
    need(len(det)==8,'Se esperaban ocho detalles; revisar cambios de alcance')
    pairs={(int(r['AGRUPACION']),r['ASIGNACION_ID']) for r in det}
    need(pairs=={(g,a) for g,a in OLD.items()}|{(v[1],a) for a,v in MAP.items()},'Relaciones diferentes de Oracle revisado')
    for r in ctrl:
        g=int(r['AGRUPACION'])
        if g in OLD:
            need(r['FECHA_PAGO'].startswith('2026-07-'),'Control historico no corresponde a julio')
            if g!=514957: need(r['FECHA_ENVIO'] is not None,'Historico enviado perdio su fecha')
        else:
            a=next(a for a,v in MAP.items() if v[1]==g); v=MAP[a]
            need(r['ACCNT_ID']=='Contado' and r['FECHA_ENVIO'] is None and r['CLIENTE_SAP']==v[2]
                 and D(r['IMPORTE'])==D(v[3]),'Control octubre inesperado')
    rf=data['REGISTRO_FISCAL']; rd=data['REGISTRO_FISCAL_DETALLE']
    facts={v[0] for v in MAP.values()}
    need(len(rf)==4 and {r['FACTURA'] for r in rf}==facts,'Cabeceras fiscales incompletas')
    counts={'V0179-67553':8,'V0225-134949':8,'V0440-70133':6,'V0822-105802':4}
    need(len(rd)==26 and all(sum(r['FACTURA']==f for r in rd)==n for f,n in counts.items()),'Detalle fiscal incompleto')
    need(len({(r['FACTURA'],r['NUM_LINEA']) for r in rd})==26,'Detalle fiscal duplicado')
    lines=['USE [T3QA];','SET NOCOUNT ON; SET XACT_ABORT ON;',
      "IF @@TRANCOUNT<>0 THROW 52920,'No usar transaccion externa.',1;",
      'BEGIN TRY BEGIN TRANSACTION;',
      f"IF NOT EXISTS(SELECT 1 FROM [{S}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1 AND Fase='CAPTURADO') THROW 52921,'La captura no esta disponible para carga.',1;"]
    for table,m in schema.items():
        lines += [f"IF EXISTS(SELECT 1 FROM [{S}].[Origen_{table}]) THROW 52922,'Origen ya cargado parcialmente.',1;"]
        cols=','.join('['+c+']' for c,_,_ in m['columns'])
        for row in data[table]:
            vals=','.join(literal(row[c],t,size) for c,t,size in m['columns'])
            lines += [f'INSERT [{S}].[Origen_{table}]({cols}) VALUES({vals});']
    maximum=max(int(meta['MAX_CONTROL']),int(meta['MAX_DETALLE']))
    lines += [f"UPDATE [{S}].Estado SET Fase='CARGADO',MaxOrigen={maximum},HashOrigen='{digest.hexdigest()}' WHERE Id=1;",
      'COMMIT; END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;',
      f'SELECT * FROM [{S}].Estado;']
    output.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('VALIDADO: 4 cobranzas, 8 controles, 8 relaciones, 4 cabeceras, 26 detalles.')
    print('Generado:',output)

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--entrada',type=Path,required=True)
    args=p.parse_args()
    generate(args.entrada,HERE/'03_MSSQL_CARGAR_ORIGEN.sql')
