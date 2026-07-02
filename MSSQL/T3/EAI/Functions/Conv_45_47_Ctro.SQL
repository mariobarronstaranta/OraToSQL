CREATE FUNCTION EAI.Conv_45_47_Ctro
(
    @sDist VARCHAR(3)
)
RETURNS CHAR(4)
AS
BEGIN
    DECLARE @sReturn CHAR(4);

    SET @sReturn =
        CASE @sDist
            WHEN '011' THEN 'MX10'
            WHEN '022' THEN 'MX11'
            WHEN '023' THEN 'MX12'
            WHEN '026' THEN 'MX13'
            WHEN '050' THEN 'MX14'
            WHEN '051' THEN 'MX15'
            WHEN '061' THEN 'MX16'
            WHEN '071' THEN 'MX17'
            WHEN '083' THEN 'MX18'
            WHEN '101' THEN 'MX19'
            WHEN '102' THEN 'MX20'
            WHEN '103' THEN 'MX21'
            WHEN '110' THEN 'MX23'
            WHEN '113' THEN 'MX22'
            WHEN '125' THEN 'MX24'
            WHEN '131' THEN 'MX25'
            WHEN '141' THEN 'MX26'
            WHEN '144' THEN 'MX27'
            WHEN '145' THEN 'MX28'
            WHEN '151' THEN 'MX29'
            WHEN '165' THEN 'MX30'
            WHEN '167' THEN 'MX31'
            WHEN '170' THEN 'MX32'
            WHEN '181' THEN 'MX33'
            WHEN '182' THEN 'MX34'
            WHEN '185' THEN 'MX35'
            WHEN '186' THEN 'MX36'
            WHEN '187' THEN 'MX37'
            WHEN '193' THEN 'MX38'
            WHEN '196' THEN 'MX39'
            WHEN '197' THEN 'MX40'
            WHEN '198' THEN 'MX41'
            WHEN '202' THEN 'MX42'
            WHEN '214' THEN 'MX43'
            WHEN '221' THEN 'MX44'
            WHEN '224' THEN 'MX45'
            WHEN '230' THEN 'MX46'
            WHEN '243' THEN 'MX47'
            WHEN '251' THEN 'MX48'
            WHEN '253' THEN 'MX49'
            WHEN '255' THEN 'MX50'
            WHEN '262' THEN 'MX51'
            WHEN '264' THEN 'MX52'
            WHEN '266' THEN 'MX53'
            WHEN '271' THEN 'MX54'
            WHEN '273' THEN 'MX55'
            WHEN '281' THEN 'MX56'
            WHEN '282' THEN 'MX57'
            WHEN '283' THEN 'MX58'
            WHEN '295' THEN 'MX59'
            WHEN '302' THEN 'MX60'
            WHEN '304' THEN 'MX61'
            WHEN '305' THEN 'MX62'
            WHEN '307' THEN 'MX63'
            WHEN '310' THEN 'MX64'
            WHEN '321' THEN 'MX65'
            WHEN '333' THEN 'MX66'
            WHEN '424' THEN 'MX67'
            WHEN '441' THEN 'MX68'
            WHEN '444' THEN 'MX69'
            WHEN '500' THEN 'MX70'
            WHEN '600' THEN 'MX71'
            WHEN '631' THEN 'MX72'
            WHEN '700' THEN 'MX73'
            WHEN '730' THEN 'MX74'
            ELSE '    '
        END;

    RETURN @sReturn;
END;
GO
