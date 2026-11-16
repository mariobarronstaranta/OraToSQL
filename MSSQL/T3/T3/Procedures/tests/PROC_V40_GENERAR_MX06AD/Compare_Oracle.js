// Auditoria estatica: ejecutar desde la raiz del repositorio con node <este archivo>.
// No conecta bases de datos ni cambia el procedimiento. No demuestra equivalencia funcional.
const fs = require('fs');
function read(path) {
  const b = fs.readFileSync(path);
  return b[0] === 255 && b[1] === 254 ? b.subarray(2).toString('utf16le') : b.toString('utf8');
}
function stripComments(s) {
  // Conservar saltos de linea para mantener referencias al archivo.
  let out = '', quote = false, block = false, line = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i], next = s[i + 1];
    if (line) { if (c === '\n') { line = false; out += c; } else out += ' '; continue; }
    if (block) { if (c === '*' && next === '/') { block = false; out += '  '; i++; } else out += c === '\n' ? c : ' '; continue; }
    if (c === "'") { out += c; if (quote && next === "'") { out += next; i++; } else quote = !quote; continue; }
    if (!quote && c === '-' && next === '-') { line = true; out += '  '; i++; continue; }
    if (!quote && c === '/' && next === '*') { block = true; out += '  '; i++; continue; }
    out += c;
  }
  return out;
}
function statementEnd(s, start) {
  let q = false;
  for (let i = start; i < s.length; i++) {
    if (s[i] === "'") { if (q && s[i + 1] === "'") i++; else q = !q; }
    else if (!q && s[i] === ';') return i;
  }
  throw new Error('Sentencia sin terminador');
}
function splitTop(s, separator) {
  let d = 0, q = false, start = 0, parts = [];
  for (let i = 0; i < s.length; i++) {
    if (s[i] === "'") { if (q && s[i + 1] === "'") i++; else q = !q; continue; }
    if (q) continue;
    if (s[i] === '(') d++;
    if (s[i] === ')') d--;
    if (!d && s.slice(i, i + separator.length) === separator) {
      parts.push(s.slice(start, i).trim()); i += separator.length - 1; start = i + 1;
    }
  }
  parts.push(s.slice(start).trim()); return parts;
}
function assignments(text, sql) {
  const regex = sql ? /^[ \t]*SET\s+@(\w+)\s*=\s*/gmi : /^[ \t]*(\w+)\s*:=\s*/gmi;
  const result = [];
  for (const m of text.matchAll(regex)) {
    const end = statementEnd(text, m.index + m[0].length);
    result.push({ variable: m[1].toLowerCase(), line: text.slice(0, m.index).split('\n').length,
      expression: text.slice(m.index + m[0].length, end).trim() });
  }
  return result;
}
function norm(s) {
  // No normalizar literales: espacios, mayusculas y acentos forman parte del payload.
  return s.replace(/'(?:''|[^'])*'|[^']+/g, part => part.startsWith("'") ? part :
    part.toLowerCase().replace(/@/g, '').replace(/\b(doc|item|reg|inf|ped|cma|env|info)\./g, '$1_')
      .replace(/\bt3\./g, '').replace(/\s+/g, ''));
}
function fields(a, sql) {
  const e = a.expression;
  const parts = sql && /^CONCAT\(/i.test(e) ? splitTop(e.slice(e.indexOf('(') + 1, -1), ',') : splitTop(e, '||');
  return parts.map(norm);
}
function lcs(a, b) {
  const dp = Array.from({length: a.length + 1}, () => Array(b.length + 1).fill(0));
  for (let i = a.length - 1; i >= 0; i--) for (let j = b.length - 1; j >= 0; j--)
    dp[i][j] = a[i].key === b[j].key ? 1 + dp[i+1][j+1] : Math.max(dp[i+1][j], dp[i][j+1]);
  let i = 0, j = 0, del = [], add = [];
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i].key === b[j].key) { i++; j++; }
    else if (i < a.length && (j === b.length || dp[i+1][j] >= dp[i][j+1])) del.push(a[i++]);
    else add.push(b[j++]);
  }
  return { oracleOnly: del, sqlOnly: add };
}
const op = 'ORA/T3/T3/Procedures/PROC_V40_GENERAR_MX06AD.SQL';
const sp = 'MSSQL/T3/T3/Procedures/PROC_V40_GENERAR_MX06AD_CORREGIDO.sql';
const o = stripComments(read(op)), s = stripComments(read(sp));
const oa = assignments(o, false), sa = assignments(s, true);
const report = { source: { oracle: op, sql: sp }, segments: {}, numericAssignments: {}, constants: {} };
function cursorColumns(text, sql) {
  const re=sql ? /DECLARE (Scr\w+) CURSOR LOCAL FORWARD_ONLY STATIC FOR\s+SELECT\s+/gi : /CURSOR (Scr\w+) IS\s+SELECT\s+/gi;
  const result={};
  for(const m of text.matchAll(re)) {
    const start=m.index+m[0].length;
    let d=0,q=false,end=-1;
    for(let i=start;i<text.length;i++) {
      if(text[i]==="'"){if(q&&text[i+1]==="'")i++;else q=!q;continue;}
      if(q)continue;
      if(text[i]==='(')d++;
      if(text[i]===')')d--;
      if(!d && /^FROM\b/i.test(text.slice(i)) && /\s/.test(text[i-1])){end=i;break;}
    }
    if(end<0)throw new Error('FROM no encontrado: '+m[1]);
    const cols=splitTop(text.slice(start,end),',');
    const key=m[1].toLowerCase();
    if(result[key] && JSON.stringify(result[key].columns)!==JSON.stringify(cols.map(norm)))throw new Error('Consultas distintas para '+key);
    result[key]={line:text.slice(0,m.index).split('\n').length,count:cols.length,columns:cols.map(norm)};
  }
  return result;
}
report.cursors={oracle:cursorColumns(o,false),sql:cursorColumns(s,true)};
for (const v of ['uheader','ulinfac','uimpfac','ucabadd','scabclie','scfdirel','srel_facturas']) {
  const a = oa.filter(x => x.variable === v), b = sa.filter(x => x.variable === v);
  // Comparar referencias de origen/literales, dejando las conversiones como diferencias a revisar.
  const aa = a.map(x => ({line:x.line, key:fields(x,false).join('|')}));
  const bb = b.map(x => ({line:x.line, key:fields(x,true).join('|')}));
  report.segments[v] = { oracleAssignments:a.length, sqlAssignments:b.length,
    oracleSeparators:a.reduce((n,x)=>n+fields(x,false).filter(p=>p==='ssepcampo').length,0),
    sqlSeparators:b.reduce((n,x)=>n+fields(x,true).filter(p=>p==='ssepcampo').length,0), ...lcs(aa,bb) };
}
for (const v of [...new Set(oa.filter(x=>x.variable.startsWith('n')).map(x=>x.variable))]) {
  const a=oa.filter(x=>x.variable===v), b=sa.filter(x=>x.variable===v);
  if (JSON.stringify(a.map(x=>norm(x.expression)))!==JSON.stringify(b.map(x=>norm(x.expression))))
    report.numericAssignments[v]={oracle:a,sql:b};
}
for (const v of ['sleymenor','sleyvype','sleypriv','svendornint','scompradorgln','slocalidademisor','slocalidadreceptor'])
  report.constants[v]={oracle:oa.filter(x=>x.variable===v),sql:sa.filter(x=>x.variable===v)};
if (process.argv.includes('--check-a-header')) {
  // Contrato externo de Oracle: cantidad Y orden de campos, no solo contar CONCAT.
  const header=report.segments.ucabadd;
  if (header.oracleSeparators!==76 || header.sqlSeparators!==76 ||
      header.oracleOnly.length || header.sqlOnly.length) {
    throw new Error('A_HEADER debe conservar los 76 campos y su secuencia Oracle.');
  }
  console.error('OK: A_HEADER tiene 76 campos y la misma secuencia de operandos que Oracle.');
}
console.log(JSON.stringify(report,null,2));
