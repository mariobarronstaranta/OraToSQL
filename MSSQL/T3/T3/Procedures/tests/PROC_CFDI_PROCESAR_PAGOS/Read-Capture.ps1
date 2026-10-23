function Read-PagosCapture([string]$Path) {
    $lines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).Path)
    $data = @{}; $columns = @(); $headers = @()
    for ($i=0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -match '^Seccion\s') {
            $header = $line
            $columns = @([regex]::Matches($lines[$i+1],'-+'))
            $headers = @($columns | ForEach-Object {
                $header.Substring($_.Index,[Math]::Min($_.Length,$header.Length-$_.Index)).Trim()
            })
            continue
        }
        if ($line -notmatch '^\d\d_[A-Z_]+' -or $columns.Count -eq 0) { continue }
        $row = [ordered]@{}
        for ($j=0; $j -lt $columns.Count; $j++) {
            $c=$columns[$j]
            $value = if ($line.Length -gt $c.Index) {
                $line.Substring($c.Index,[Math]::Min($c.Length,$line.Length-$c.Index))
            } else { '' }
            # Mantener espacios dentro de fragmentos de definiciones SQL.
            $row[$headers[$j]] = if ($headers[$j] -eq 'Texto') { $value } else { $value.Trim() }
        }
        $section=$row['Seccion']
        if (-not $data.ContainsKey($section)) { $data[$section]=New-Object 'Collections.Generic.List[object]' }
        $data[$section].Add([pscustomobject]$row)
    }
    foreach ($required in @('01_AMBIENTE','04_DEFINICIONES','08_PARAMETROS','11_COBERTURA_HISTORIAL','12_ASIGNACIONES_HISTORIAL','29_FIN')) {
        if (-not $data.ContainsKey($required)) { throw "Captura incompleta: falta $required" }
    }
    if (@($data['11_COBERTURA_HISTORIAL'] | Where-Object Cobertura -like 'TRUNCADO*').Count) {
        throw 'No reproducir saldos con historial truncado.'
    }
    return $data
}
function Get-CapturedModule($Data,[string]$Name) {
    $rows=@($Data['04_DEFINICIONES'] | Where-Object Nombre -eq $Name)
    if (-not $rows.Count) { throw "Falta definicion instalada de $Name" }
    $text = ($rows | Group-Object Linea | Sort-Object {[int]$_.Name} | ForEach-Object {
        $fragments=@($_.Group | Sort-Object {[int]$_.Fragmento})
        $parts=for($k=0;$k -lt $fragments.Count;$k++) {
            if ($k -lt $fragments.Count-1) { $fragments[$k].Texto.PadRight(180).Substring(0,180) }
            else { $fragments[$k].Texto.TrimEnd() }
        }
        $parts -join ''
    }) -join "`r`n"
    # Solo normalizar la declaracion del modulo para la base temporal.
    return [regex]::Replace($text,'(?im)^(CREATE|ALTER)\s+(PROCEDURE|FUNCTION)\b','CREATE OR ALTER $2')
}
function Get-CapturedDataSql($Data) {
    $script:fixture = New-Object 'Collections.Generic.List[string]'
    $script:fixture.Add('SET NOCOUNT ON;')
    function Insert-Rows([string]$Table,$Rows,[string[]]$Names) {
        foreach ($row in $Rows) {
            $values=foreach ($name in $Names) {
                $v=[string]$row.$name
                if ($v -eq 'NULL') { 'NULL' }
                else {
                    if ($v -match '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d') { $v=$v.Replace(' ','T') }
                    "N'"+$v.Replace("'","''")+"'"
                }
            }
            $script:fixture.Add('INSERT '+$Table+' (['+($Names -join '],[')+']) VALUES ('+($values -join ',')+');')
        }
    }
    Insert-Rows 'T3.ASIGNACION_PAGO' $Data['12_ASIGNACIONES_HISTORIAL'] @('Factura','Asignacion_ID','Pago_ID','Cliente_SAP','Nota_Credito','Rep_ID','Ctro','Fecha_Asignacion','Fecha_Proc_BATMD','Fecha_Trn','Valor_Pago')
    # Una fila de captura por vigencia y asignacion: tomar todas las vigencias
    # de la primera asignacion de cada cliente, sin duplicarlas por otro pago.
    foreach ($client in ($Data['13_VIGENCIA'] | Group-Object Cliente_SAP)) {
        $first=$client.Group[0].Asignacion_ID
        Insert-Rows 'T3.CLIENTE' @($client.Group | Where-Object Asignacion_ID -eq $first) @('Cliente_SAP','Fecha_Ini_Vig','Fecha_Fin_Vig','Dias_Cdto','RFC')
    }
    $maps=@(
        @('14_PAGOS','T3.PAGO',@('Pago_ID','Fecha_Trn','Fecha_Pago','Cliente_SAP','Rep_ID','Tipo_Pago','Metodo_Pago','Valor_Pago','Fecha_Proc_BATMD','Ctro')),
        @('15_REGISTRO_FISCAL','T3.REGISTRO_FISCAL',@('Factura','Tipo_Docto','Fecha_Factura')),
        @('16_TIPOS','T3.TIPO_DOCUMENTO',@('Tipo_Documento','Origen')),
        @('17_DETALLE_FISCAL','T3.REGISTRO_FISCAL_DETALLE',@('Factura','Num_Linea','Valor_Subt','Valor_IVA','Envio_Subt','Envio_IVA','Credito_Subt','Credito_IVA')),
        @('18_FACTURA_GENERAL','T3.FACTURA_GENERAL',@('Factura','Fecha_Proc_BATMD')),
        @('19_FACTURA_DETALLE','T3.FACTURA_DETALLE',@('Factura','Num_Linea','Valor_Subt','Valor_IVA','Envio_Subt','Envio_IVA','Credito_Subt','Credito_IVA')),
        @('20_PREVENTA_GENERAL','T3.PREVENTA_GENERAL',@('Factura','Referencia','Fecha_Proc_BATMD')),
        @('21_PREVENTA_DETALLE','T3.PREVENTA_DETALLE',@('Factura','Num_Linea','Valor_Subt','Valor_IVA','Envio_Subt','Envio_IVA','Credito_Subt','Credito_IVA')),
        @('22_HISTORIA_PAC','T3.CFDI_HISTORIA_DOCTO_PAC',@('Nota_Venta','Nota_Venta_CFDI')),
        @('23_UUID','T3.CFDI_DOCUMENTOS',@('Nota_Venta','Folio_Fiscal','Status')),
        @('24_CANCELACIONES','T3.DEBIT_NOTE_IFC',@('Debit_Note','Document_Date','Total_Amt'))
    )
    foreach ($map in $maps) { Insert-Rows $map[1] $Data[$map[0]] $map[2] }
    if ($Data.ContainsKey('25_COBRANZA_EXISTENTE')) { throw 'Esta reproduccion requiere adaptar la carga de cobranza existente antes de ejecutarse.' }
    $script:fixture.Add('DELETE FROM EAI_OWNER.MX_HashTable;')
    foreach ($item in $Data['26_CATALOGOS']) {
        if ($item.Target -eq 'VALOR_OMITIDO') { $item.Target='0' * [int]$item.LongitudTarget }
    }
    Insert-Rows 'EAI_OWNER.MX_HashTable' $Data['26_CATALOGOS'] @('Type','Source','Target')
    return $script:fixture -join "`r`n"
}
