/*
    Homologo SQL Server de EAI_OWNER.WA_EXECUTE_ARCHIVING (Oracle).

    Este procedimiento es un wrapper: ejecuta T3.ARCHIVING_T3 para el periodo
    fijo 2019-01-01 a 2020-12-31 con el valor 16 y confirma la transaccion.

    La firma de T3.ARCHIVING_T3 no forma parte de este repositorio. Por eso la
    llamada es posicional, como en Oracle, y no depende de nombres de parametros
    que podrian ser diferentes en la implementacion de SQL Server.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_EXECUTE_ARCHIVING]
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle no usa un manejador de excepciones: un error se propaga al
        invocador. XACT_ABORT OFF conserva ese comportamiento para errores que
        permiten continuar utilizando la transaccion del invocador.
    */
    SET XACT_ABORT OFF;

    DECLARE
        @StartedTransaction BIT = 0,
        @FechaInicial       DATE = CONVERT(date, '20190101', 112),
        @FechaFinal         DATE = CONVERT(date, '20201231', 112);

    BEGIN TRY
        /*
            Si no existe una transaccion, se crea una para que todo el proceso
            de archivado se confirme como una unidad al finalizar.
        */
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END;

        EXEC [T3].[ARCHIVING_T3]
             @FechaInicial,
             @FechaFinal,
             16;

        /*
            Equivale al COMMIT Oracle. Si el procedimiento llamado ya termino
            la transaccion, no se intenta ejecutar un COMMIT adicional.

            Si existe una unica transaccion del invocador, este COMMIT tambien
            la confirma. Esa es la situacion equivalente al COMMIT de PL/SQL.
        */
        IF @@TRANCOUNT > 0
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        /*
            Un error se vuelve a propagar, igual que en Oracle. Solo se revierte
            la transaccion creada aqui para no dejar una transaccion abierta en
            la conexion; una transaccion preexistente sigue bajo control del
            invocador.
        */
        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
