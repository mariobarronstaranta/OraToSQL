CREATE FUNCTION EAI.CONV_ALM_TO_DIST
(
    @sPlant VARCHAR(3)
)
RETURNS INT
AS
BEGIN
    DECLARE @nReturn INT;

    SELECT @nReturn =
        CASE
            WHEN @sPlant = 'C10' THEN 11
            WHEN @sPlant = 'C11' THEN 22
            WHEN @sPlant = 'C12' THEN 23
            WHEN @sPlant = 'C13' THEN 26
            WHEN @sPlant = 'C14' THEN 50
            WHEN @sPlant = 'C15' THEN 51
            WHEN @sPlant = 'C16' THEN 61
            WHEN @sPlant = 'C17' THEN 71
            WHEN @sPlant = 'C18' THEN 83
            WHEN @sPlant = 'C19' THEN 101

            WHEN @sPlant = 'C20' THEN 102
            WHEN @sPlant = 'C21' THEN 103
            WHEN @sPlant = 'C23' THEN 110
            WHEN @sPlant = 'C22' THEN 113
            WHEN @sPlant = 'C24' THEN 125
            WHEN @sPlant = 'C25' THEN 131
            WHEN @sPlant = 'C26' THEN 141
            WHEN @sPlant = 'C27' THEN 144
            WHEN @sPlant = 'C28' THEN 145
            WHEN @sPlant = 'C29' THEN 151

            WHEN @sPlant = 'C30' THEN 165
            WHEN @sPlant = 'C31' THEN 167
            WHEN @sPlant = 'C32' THEN 170
            WHEN @sPlant = 'C33' THEN 181
            WHEN @sPlant = 'C34' THEN 182
            WHEN @sPlant = 'C35' THEN 185
            WHEN @sPlant = 'C36' THEN 186
            WHEN @sPlant = 'C37' THEN 187
            WHEN @sPlant = 'C38' THEN 193
            WHEN @sPlant = 'C39' THEN 196

            WHEN @sPlant = 'C40' THEN 197
            WHEN @sPlant = 'C41' THEN 198
            WHEN @sPlant = 'C42' THEN 202
            WHEN @sPlant = 'C43' THEN 214
            WHEN @sPlant = 'C44' THEN 221
            WHEN @sPlant = 'C45' THEN 224
            WHEN @sPlant = 'C46' THEN 230
            WHEN @sPlant = 'C47' THEN 243
            WHEN @sPlant = 'C48' THEN 251
            WHEN @sPlant = 'C49' THEN 253

            WHEN @sPlant = 'C50' THEN 255
            WHEN @sPlant = 'C51' THEN 262
            WHEN @sPlant = 'C52' THEN 264
            WHEN @sPlant = 'C53' THEN 266
            WHEN @sPlant = 'C54' THEN 271
            WHEN @sPlant = 'C55' THEN 273
            WHEN @sPlant = 'C56' THEN 281
            WHEN @sPlant = 'C57' THEN 282
            WHEN @sPlant = 'C58' THEN 283
            WHEN @sPlant = 'C59' THEN 295

            WHEN @sPlant = 'C60' THEN 302
            WHEN @sPlant = 'C61' THEN 304
            WHEN @sPlant = 'C62' THEN 305
            WHEN @sPlant = 'C63' THEN 307
            WHEN @sPlant = 'C64' THEN 310
            WHEN @sPlant = 'C65' THEN 321
            WHEN @sPlant = 'C66' THEN 333
            WHEN @sPlant = 'C67' THEN 424
            WHEN @sPlant = 'C68' THEN 441
            WHEN @sPlant = 'C69' THEN 444

            WHEN @sPlant = 'C70' THEN 500
            WHEN @sPlant = 'C71' THEN 600
            WHEN @sPlant = 'C72' THEN 631
            WHEN @sPlant = 'C73' THEN 700
            WHEN @sPlant = 'C74' THEN 730

            -- Febrero 2010 - Inicio de Operación de Subsidiaria

            WHEN @sPlant = 'M10' THEN 11
            WHEN @sPlant = 'M11' THEN 22
            WHEN @sPlant = 'M12' THEN 23
            WHEN @sPlant = 'M13' THEN 26
            WHEN @sPlant = 'M14' THEN 50
            WHEN @sPlant = 'M15' THEN 51
            WHEN @sPlant = 'M16' THEN 61
            WHEN @sPlant = 'M17' THEN 71
            WHEN @sPlant = 'M18' THEN 83
            WHEN @sPlant = 'M19' THEN 101

            WHEN @sPlant = 'M20' THEN 102
            WHEN @sPlant = 'M21' THEN 103
            WHEN @sPlant = 'M23' THEN 110
            WHEN @sPlant = 'M22' THEN 113
            WHEN @sPlant = 'M24' THEN 125
            WHEN @sPlant = 'M25' THEN 131
            WHEN @sPlant = 'M26' THEN 141
            WHEN @sPlant = 'M27' THEN 144
            WHEN @sPlant = 'M28' THEN 145
            WHEN @sPlant = 'M29' THEN 151

            WHEN @sPlant = 'M30' THEN 165
            WHEN @sPlant = 'M31' THEN 167
            WHEN @sPlant = 'M32' THEN 170
            WHEN @sPlant = 'M33' THEN 181
            WHEN @sPlant = 'M34' THEN 182
            WHEN @sPlant = 'M35' THEN 185
            WHEN @sPlant = 'M36' THEN 186
            WHEN @sPlant = 'M37' THEN 187
            WHEN @sPlant = 'M38' THEN 193
            WHEN @sPlant = 'M39' THEN 196

            WHEN @sPlant = 'M40' THEN 197
            WHEN @sPlant = 'M41' THEN 198
            WHEN @sPlant = 'M42' THEN 202
            WHEN @sPlant = 'M43' THEN 214
            WHEN @sPlant = 'M44' THEN 221
            WHEN @sPlant = 'M45' THEN 224
            WHEN @sPlant = 'M46' THEN 230
            WHEN @sPlant = 'M47' THEN 243
            WHEN @sPlant = 'M48' THEN 251
            WHEN @sPlant = 'M49' THEN 253

            WHEN @sPlant = 'M50' THEN 255
            WHEN @sPlant = 'M51' THEN 262
            WHEN @sPlant = 'M52' THEN 264
            WHEN @sPlant = 'M53' THEN 266
            WHEN @sPlant = 'M54' THEN 271
            WHEN @sPlant = 'M55' THEN 273
            WHEN @sPlant = 'M56' THEN 281
            WHEN @sPlant = 'M57' THEN 282
            WHEN @sPlant = 'M58' THEN 283
            WHEN @sPlant = 'M59' THEN 295

            WHEN @sPlant = 'M60' THEN 302
            WHEN @sPlant = 'M61' THEN 304
            WHEN @sPlant = 'M62' THEN 305
            WHEN @sPlant = 'M63' THEN 307
            WHEN @sPlant = 'M64' THEN 310
            WHEN @sPlant = 'M65' THEN 321
            WHEN @sPlant = 'M66' THEN 333
            WHEN @sPlant = 'M67' THEN 424
            WHEN @sPlant = 'M68' THEN 441
            WHEN @sPlant = 'M69' THEN 444

            WHEN @sPlant = 'M70' THEN 500
            WHEN @sPlant = 'M71' THEN 600
            WHEN @sPlant = 'M72' THEN 631
            WHEN @sPlant = 'M73' THEN 700
            WHEN @sPlant = 'M74' THEN 730

            WHEN @sPlant = 'M96' THEN 731
            WHEN @sPlant = 'M99' THEN 445

            ELSE 0
        END;

    RETURN @nReturn;
END;
GO
