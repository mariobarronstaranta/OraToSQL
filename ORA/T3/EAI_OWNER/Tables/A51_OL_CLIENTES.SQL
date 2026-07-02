create or replace FUNCTION       "CONV_45_47_CTRO" 
   ( sDist VARCHAR2 )  RETURN  VARCHAR2
IS
   sReturn VARCHAR2(4) ;
BEGIN
   SELECT CASE
          WHEN sDist = '011' THEN 'MX10'
          WHEN sDist = '022' THEN 'MX11'
          WHEN sDist = '023' THEN 'MX12'
          WHEN sDist = '026' THEN 'MX13'
          WHEN sDist = '050' THEN 'MX14'
          WHEN sDist = '051' THEN 'MX15'
          WHEN sDist = '061' THEN 'MX16'
          WHEN sDist = '071' THEN 'MX17'
          WHEN sDist = '083' THEN 'MX18'
          WHEN sDist = '101' THEN 'MX19'
       --
          WHEN sDist = '102' THEN 'MX20'
          WHEN sDist = '103' THEN 'MX21'
          WHEN sDist = '110' THEN 'MX23'
          WHEN sDist = '113' THEN 'MX22'
          WHEN sDist = '125' THEN 'MX24'
          WHEN sDist = '131' THEN 'MX25'
          WHEN sDist = '141' THEN 'MX26'
          WHEN sDist = '144' THEN 'MX27'
          WHEN sDist = '145' THEN 'MX28'
          WHEN sDist = '151' THEN 'MX29'
       --
          WHEN sDist = '165' THEN 'MX30'
          WHEN sDist = '167' THEN 'MX31'
          WHEN sDist = '170' THEN 'MX32'
          WHEN sDist = '181' THEN 'MX33'
          WHEN sDist = '182' THEN 'MX34'
          WHEN sDist = '185' THEN 'MX35'
          WHEN sDist = '186' THEN 'MX36'
          WHEN sDist = '187' THEN 'MX37'
          WHEN sDist = '193' THEN 'MX38'
          WHEN sDist = '196' THEN 'MX39'
       --
          WHEN sDist = '197' THEN 'MX40'
          WHEN sDist = '198' THEN 'MX41'
          WHEN sDist = '202' THEN 'MX42'
          WHEN sDist = '214' THEN 'MX43'
          WHEN sDist = '221' THEN 'MX44'
          WHEN sDist = '224' THEN 'MX45'
          WHEN sDist = '230' THEN 'MX46'
          WHEN sDist = '243' THEN 'MX47'
          WHEN sDist = '251' THEN 'MX48'
          WHEN sDist = '253' THEN 'MX49'
       --
          WHEN sDist = '255' THEN 'MX50'
          WHEN sDist = '262' THEN 'MX51'
          WHEN sDist = '264' THEN 'MX52'
          WHEN sDist = '266' THEN 'MX53'
          WHEN sDist = '271' THEN 'MX54'
          WHEN sDist = '273' THEN 'MX55'
          WHEN sDist = '281' THEN 'MX56'
          WHEN sDist = '282' THEN 'MX57'
          WHEN sDist = '283' THEN 'MX58'
          WHEN sDist = '295' THEN 'MX59'
       --
          WHEN sDist = '302' THEN 'MX60'
          WHEN sDist = '304' THEN 'MX61'
          WHEN sDist = '305' THEN 'MX62'
          WHEN sDist = '307' THEN 'MX63'
          WHEN sDist = '310' THEN 'MX64'
          WHEN sDist = '321' THEN 'MX65'
          WHEN sDist = '333' THEN 'MX66'
          WHEN sDist = '424' THEN 'MX67'
          WHEN sDist = '441' THEN 'MX68'
          WHEN sDist = '444' THEN 'MX69'
       --
		  WHEN sDist = '500' THEN 'MX70'
          WHEN sDist = '600' THEN 'MX71'
          WHEN sDist = '631' THEN 'MX72'
          WHEN sDist = '700' THEN 'MX73'
          WHEN sDist = '730' THEN 'MX74'
		  ELSE
		     '    '
		  END
      INTO sReturn
      FROM DUAL ;
   RETURN sReturn ;
END Conv_45_47_Ctro ;
 
 