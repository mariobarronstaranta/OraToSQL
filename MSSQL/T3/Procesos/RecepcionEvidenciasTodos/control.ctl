<?xml version="1.0"?>
<!-- Formato bcp: cargar cada registro completo; moveInfo.sql interpreta el CSV. -->
<BCPFORMAT xmlns="http://schemas.microsoft.com/sqlserver/2004/bulkload/format" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <RECORD><FIELD ID="1" xsi:type="CharTerm" TERMINATOR="&#x0A;" MAX_LENGTH="8000" /></RECORD>
  <ROW><COLUMN SOURCE="1" NAME="LINEA" xsi:type="SQLVARYCHAR" /></ROW>
</BCPFORMAT>