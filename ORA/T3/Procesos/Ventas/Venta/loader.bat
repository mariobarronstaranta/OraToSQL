SET NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
Rem Loading to input Table.
sqlplus CCC_CARGA/MILAN$2023$PMO@owba030p @E:\IntegrationToolBox\Venta\truncate_ldr.sql
sqlldr userid=CCC_CARGA/MILAN$2023$PMO@owba030p control=E:\IntegrationToolBox\Venta\CONTROL.ctl log=process.log
Rem Add to Aggregation Table.
sqlplus CCC_CARGA/MILAN$2023$PMO@owba030p @E:\IntegrationToolBox\Venta\moveDailyInfo.sql > moveDailyInfo.log
Rem Backup processed File.
echo f |xcopy factura.ready.doc factura.processed.%date:~-4%%date:~-10,2%%date:~-7,2%.doc
move /y factura.processed.*.doc processed\factura.processed.%date:~-4%%date:~-10,2%%date:~-7,2%.%time:~1,1%.%time:~3,2%.%time:~6,2%.doc
echo f |xcopy process.log processed\factura.log.%date:~-4%%date:~-10,2%%date:~-7,2%.%time:~1,1%.%time:~3,2%.%time:~6,2%.txt
Rem Ending Sales-Information load up proccess
Rem Start CControl calcualtions.
Rem Please Start CControl calcualtions manually.
Rem Finished CControl calcualtions.