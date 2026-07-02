CREATE OR ALTER PROCEDURE dbo.T3R_REPLICA_SALESDOC
    @sTipo_Act VARCHAR(50) = 'Full'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Registrar inicio del proceso
        UPDATE dbo.T3R_STATUS 
        SET Start_Date = GETDATE(), End_Date = NULL
        WHERE PROCEDURE = 'REPLICA T3R_SALES_DOCS';

        -- Lógica DELTA: Solo inserta documentos nuevos o modificados
        IF @sTipo_Act = 'Delta'
        BEGIN
            INSERT INTO dbo.T3R_SALES_DOCS_OLD
                (Doc_Date, Distributor, Customer, Doc_Num_R3, Doc_Ord_R3, 
                 Doc_Num_Ref1, Doc_Num_Ref2, Doc_Type, Doc_Status, 
                 Doc_NetAmt, Doc_TaxAmt, Doc_Qty)
            SELECT 
                A.Doc_Date, A.Distributor, A.Customer, A.Doc_Num_R3, A.Doc_Ord_R3,
                A.Doc_Num_Ref1, A.Doc_Num_Ref2, A.Doc_Type, A.Doc_Status,
                A.Doc_NetAmt, A.Doc_TaxAmt, A.Doc_Qty
            FROM dbo.T3R_SALES_DOCS A
            LEFT JOIN dbo.T3R_SALES_DOCS_OLD B 
                ON A.Doc_Num_R3 = B.Doc_Num_R3
            WHERE B.Doc_Num_R3 IS NULL 
              AND B.Doc_Num_Ref2 IS NULL;
        END
        ELSE
        BEGIN
            -- Lógica FULL: Recarga completa
            TRUNCATE TABLE dbo.T3R_SALES_DOCS_OLD;

            INSERT INTO dbo.T3R_SALES_DOCS_OLD
                (Doc_Date, Distributor, Customer, Doc_Num_R3, Doc_Ord_R3, 
                 Doc_Num_Ref1, Doc_Num_Ref2, Doc_Type, Doc_Status, 
                 Doc_NetAmt, Doc_TaxAmt, Doc_Qty)
            SELECT 
                Doc_Date, Distributor, Customer, Doc_Num_R3, Doc_Ord_R3,
                Doc_Num_Ref1, Doc_Num_Ref2, Doc_Type, Doc_Status,
                Doc_NetAmt, Doc_TaxAmt, Doc_Qty
            FROM dbo.T3R_SALES_DOCS;
        END

        -- Registrar finalización
        UPDATE dbo.T3R_STATUS 
        SET End_Date = GETDATE()
        WHERE PROCEDURE = 'REPLICA T3R_SALES_DOCS';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        -- Log de error (opcional, requiere tabla de auditoría)
        INSERT INTO dbo.T3R_ERROR_LOG (Procedure_Name, Error_Message, Error_Time)
        VALUES ('T3R_REPLICA_SALESDOC', ERROR_MESSAGE(), GETDATE());
        
        THROW;
    END CATCH;
END;
