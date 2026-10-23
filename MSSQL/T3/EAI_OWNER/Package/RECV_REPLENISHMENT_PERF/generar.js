const fs = require('fs');
const path = require('path');
const source = fs.readFileSync(process.argv[2], 'utf8').replace(/\r/g, '');
const match = source.match(/ALTER\s+PROCEDURE\s+(\[EAI_OWNER\]\.\[SF_PROC_REPLENISHMENT\][\s\S]*)/);
if (!match) throw Error('No se encontro el procedimiento');
const before = match[1].replace(/\nGO\s*$/i, '').trim();
const pattern = /(?:DELETE FROM \[EAI_OWNER\]\.\[TMP_DOCUMENT_(?:HEADER|DETAIL|CONDITIONS|PARTNERS)\]|UPDATE \[EAI_OWNER\]\.\[TMP_DOCUMENT_HEADER\]\s+SET [^;]+?)\s+WHERE ReferenceID = @sReferenceID;/g;
const blocks = [...before.matchAll(pattern)];
if (blocks.length !== 7 || blocks.filter(m=>m[0].startsWith('DELETE')).length !== 4)
    throw Error('Se esperaban 4 DELETE y 3 UPDATE');
const after = before.replace(pattern, old => {
    const seek = old.replace('WHERE ReferenceID = @sReferenceID;',
        'WHERE ReferenceID = CONVERT(varchar(50),@sReferenceID)\n' +
        '                      AND CONVERT(nvarchar(50),ReferenceID) = @sReferenceID;');
    return `/* RR_REFERENCEID_BEGIN */
            IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@sReferenceID)))
               = CONVERT(varbinary(max),@sReferenceID)
            BEGIN
                ${seek}
            END
            ELSE
            BEGIN
                ${old}
            END;
            /* RR_REFERENCEID_END */`;
});
const read = n => fs.readFileSync(path.join(__dirname,n),'utf8');
const write = (n,s) => fs.writeFileSync(path.join(__dirname,n),'\uFEFF'+s,'utf8');
const literal = s => "N'"+s.replace(/'/g,"''")+"'";
write('02_PATCH_REFERENCEID.sql',read('guard_inicio.txt')+
    'DECLARE @Antes nvarchar(max)='+literal(before)+';\n'+
    'DECLARE @Despues nvarchar(max)='+literal(after)+';\n'+read('guard_fin.txt'));
write('respaldo_recibido.sql',
    'SET ANSI_NULLS ON;\nGO\nSET QUOTED_IDENTIFIER ON;\nGO\nCREATE OR ALTER PROCEDURE '+before);
console.log('Generados parche reversible y respaldo: 4 DELETE y 3 UPDATE.');
