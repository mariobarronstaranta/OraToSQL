LOAD DATA 
INFILE 'E:\IntegrationToolBox\RecepcionEvidenciasTodos\EvidenciaEntrega.csv' 
BADFILE 'E:\IntegrationToolBox\RecepcionEvidenciasTodos\EvidenciaEntrega.ready.bad'
DISCARDFILE 'E:\IntegrationToolBox\RecepcionEvidenciasTodos\EvidenciaEntrega.ready.dsc'
APPEND
INTO TABLE EAI.LDR_EVIDENCIA_DELIVERY
FIELDS TERMINATED BY ','
(
Jefe_territorial,
Cliente,
Sucursal,
ID_Registro,
Fecha_de_Entrega,
Created,
Attachments,
Comentarios,
Folio_Ticket,
NoSAP,
Created_By,
Modified,
Modified_By,
NoFactura,
PedidoSAP,
Status,
Id_Tienda,
Tienda,
Tienda_SF,
FolioRecepcion_SF,
VolumenTicket,
VolumenNota,
Volumen_SF,
CoincideFolioRecepcion,
CoincideTienda,
CheckVolNotavsVolTicket,
CheckVolNotavsVolSF,
Revisar,
Comentarios_comparativa,
Refacturacion,
FolioRefacturacion,
VersionApp )
