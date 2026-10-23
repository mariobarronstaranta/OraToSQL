sqlplus EAI_APPS/TURIN$2023$PMO@owba030p @Header.sql
COPY SALES_*.csv Y:\CifrasControl\Outbound\SALES\*.*
COPY SALES_*.csv Processed\*.*
DEL  SALES_*.csv 