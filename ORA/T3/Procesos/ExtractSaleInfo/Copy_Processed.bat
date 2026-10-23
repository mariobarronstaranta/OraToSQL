@echo off
set hournum=%time:~0,2%
if %hournum% gtr 9 (set timeback=_%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%) else (set timeback=_%date:~10,4%%date:~4,2%%date:~7,2%_0%time:~1,1%%time:~3,2%)
Echo %~n1%timeback%%~x1
Echo copy %~n1%~x1 processed\%~n1%timeback%%~x1
copy %~n1%~x1 processed\%~n1%timeback%%~x1