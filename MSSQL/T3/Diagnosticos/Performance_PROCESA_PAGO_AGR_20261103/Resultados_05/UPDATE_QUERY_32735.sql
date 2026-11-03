(@nDias numeric(18,0))UPDATE Cobza
        SET Asignacion_Central = Acc.Assignment
        FROM T3.CFDI_Cobranza AS Cobza
        INNER JOIN EAI_Owner.tmp_Account_Header AS Acc
            ON SUBSTRING(Cobza.Asignacion_ID, 3, 10)
             = Acc.ClearingDocNumber
           AND Acc.FiscalYear = CONVERT(VARCHAR(4), YEAR(GETDATE()))
        INNER JOIN T3.Registro_Fiscal AS RF
            ON RF.Factura = Cobza.Factura
        -- Limite de medianoche: compara con >, por lo que excluye exactamente
        -- las 00:00 del dia limite. GETDATE se vuelve a evaluar en otros pasos.
        WHERE Cobza.Fecha_Proceso >
              CAST(DATEADD(DAY, -ISNULL(@nDias, 0), GETDATE()) AS DATE)
          -- Descarta coincidencia con entrega, valores reservados, factura
          -- seguida de coma, prefijo 1-1 y referencia fiscal. Si las expresiones
          -- quedan NULL, las comparaciones no pasan. No asigna si ya habia valor.
          AND ISNULL(Acc.Assignment, RF.Entrega) <> RF.Entrega
          AND ISNULL(Acc.Assignment, RF.Entrega) <> 'B001 - Bank I'
          AND ISNULL(Acc.Assignment, RF.Entrega) <> Cobza.Factura + ','
          AND ISNULL(Acc.Assignment, RF.Entrega) NOT LIKE '1-1%'
          AND ISNULL(Acc.Assignment, RF.Entrega) <> RF.Referencia
          AND Cobza.Asignacion_Central IS NULL