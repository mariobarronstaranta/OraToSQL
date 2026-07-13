CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_REP_MASTERDATA]
(
    @pInsert INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sReference        VARCHAR(30)  = NULL,
        @sErrorCode        VARCHAR(30)  = NULL,
        @sMsg              VARCHAR(300) = NULL,
        @nPedidos          INT          = 0,
        @nPID              INT          = NULL,
        @nProceso          INT          = 0;

    BEGIN TRY
        BEGIN TRAN;

        /*
            Origen equivalente al cursor Oracle ScrReps.

            Nota:
            Se usa ROW_NUMBER para evitar duplicados por Cliente_SAP.
            En Oracle, si existían duplicados, el cursor podía ejecutar múltiples updates/inserts.
            En SQL Server esto puede causar conflictos, por lo que se conserva una sola fila por Cliente_SAP.
        */
        ;WITH SrcBase AS
        (
            SELECT
                A.Stock_Partner_Resource AS Cliente_SAP,
                A.Resource_Name          AS Nombre_Rep,
                REPLACE(
                    REPLACE(A.IvyBase__Username__c, 'petra3.', ''),
                    'PETRA3.', ''
                ) AS eMail
            FROM [EAI_OWNER].[VANS_Vigentes] A
            WHERE A.Name LIKE 'VAN%'
              AND A.Stock_Partner_Resource NOT LIKE '%RESOURCE%'
        ),
        SrcDedup AS
        (
            SELECT
                Cliente_SAP,
                Nombre_Rep,
                eMail,
                ROW_NUMBER() OVER
                (
                    PARTITION BY Cliente_SAP
                    ORDER BY Cliente_SAP
                ) AS rn
            FROM SrcBase
        ),
        Src AS
        (
            SELECT
                S.Cliente_SAP,
                S.Nombre_Rep,
                S.eMail,
                B.Nombre,
                COALESCE(B.Correo_Electronico, 'NULL') AS Correo_Electronico,
                CASE
                    WHEN B.Cliente_SAP IS NOT NULL THEN 'UPDATE'
                    ELSE 'INSERT'
                END AS Accion
            FROM SrcDedup S
            LEFT JOIN [EAI_OWNER].[Cat_Reps] B
                ON S.Cliente_SAP = B.Cliente_SAP
            WHERE S.rn = 1
        )
        UPDATE CR
           SET CR.Correo_Electronico  = S.eMail,
               CR.Ultima_Modificacion = GETDATE(),
               CR.ModificadoPor       = 'REPLICATE'
        FROM [EAI_OWNER].[Cat_Reps] CR
        INNER JOIN Src S
            ON CR.Cliente_SAP = S.Cliente_SAP
        WHERE S.Accion = 'UPDATE'
          AND LEN(LTRIM(RTRIM(COALESCE(S.Correo_Electronico, 'NULL')))) < 5
          AND LEN(LTRIM(RTRIM(COALESCE(S.eMail, '')))) > 0;

        SET @nProceso = @@ROWCOUNT;

        /*
            Inserción de nuevos representantes.
            Respeta la lógica Oracle:
            solo inserta cuando NVL(pInsert,0) > 0.
        */
        IF COALESCE(@pInsert, 0) > 0
        BEGIN
            ;WITH SrcBase AS
            (
                SELECT
                    A.Stock_Partner_Resource AS Cliente_SAP,
                    A.Resource_Name          AS Nombre_Rep,
                    REPLACE(
                        REPLACE(A.IvyBase__Username__c, 'petra3.', ''),
                        'PETRA3.', ''
                    ) AS eMail
                FROM [EAI_OWNER].[VANS_Vigentes] A
                WHERE A.Name LIKE 'VAN%'
                  AND A.Stock_Partner_Resource NOT LIKE '%RESOURCE%'
            ),
            SrcDedup AS
            (
                SELECT
                    Cliente_SAP,
                    Nombre_Rep,
                    eMail,
                    ROW_NUMBER() OVER
                    (
                        PARTITION BY Cliente_SAP
                        ORDER BY Cliente_SAP
                    ) AS rn
                FROM SrcBase
            )
            INSERT INTO [EAI_OWNER].[Cat_Reps]
            (
                Cliente_SAP,
                Nombre,
                Correo_Electronico,
                Creacion,
                CreadoPor
            )
            SELECT
                S.Cliente_SAP,
                S.Nombre_Rep,
                S.eMail,
                GETDATE(),
                'REPLICATE'
            FROM SrcDedup S
            WHERE S.rn = 1
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM [EAI_OWNER].[Cat_Reps] CR
                  WHERE CR.Cliente_SAP = S.Cliente_SAP
              );

            SET @nPedidos = @@ROWCOUNT;
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sReference = COALESCE(@sReference, 'WA_REP_MASTERDATA');
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Se registra el error como en Oracle.
            Oracle no hace RAISE después del log; por compatibilidad,
            aquí tampoco se relanza el error.
        */
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
            JOB_PID,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging',
            @sReference,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_REP_MASTERDATA',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );
    END CATCH;
END;
GO