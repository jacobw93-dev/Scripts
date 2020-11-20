@echo off

cmd /c

SETLOCAL ENABLEEXTENSIONS EnableDelayedExpansion

NET USE * /delete /y > nul

popd

cls

pushd %~dp0

mode 120,30 > nul

chcp 65001 > nul

 

set "cust_pause=Naciśnij [Spacja] lub [Enter] aby kontynuować..."

FOR /F "skip=2 tokens=3*" %%A IN ('%windir%\System32\reg.exe query HKEY_CURRENT_USER\Software\SAP\SAPLogon\ConfigFilesLastUsed /v ConnectionConfigFile') do (set "V_SAPLOGON=%%A %%B")

 

echo:Utworzenie wpisu w rejestrze na podstawie pliku %CD%\SAPSecureLogin.reg

%windir%\System32\reg.exe import %CD%\SAPSecureLogin.reg

echo:"%cust_pause%"

pause > nul

 

echo.

echo:Kopiowanie pliku "%CD%\SAPLOGON.ini" do "%V_SAPLOGON%"

copy /Y "%CD%\SAPLOGON.ini" "%V_SAPLOGON%"

echo:"%cust_pause%"

pause > nul

 

echo.

echo:Kopiowanie pliku "%CD%\Ao_user_roaming.config" do "%appdata%\SAP\Cof\*.*"

copy /Y "%CD%\Ao_user_roaming.config" "%appdata%\SAP\Cof\*.*"

echo:"%cust_pause%"

pause > nul

 

echo.

powershell -Command "Start-Process 'cmd' -Verb RunAs -ArgumentList '/s /k "echo:Kopiowanie pliku %CD%\SAPLOGON.ini do %WINDIR%\*.*" & "copy /Y " "%CD%\SAPLOGON.ini" " " "%WINDIR%\*.*" & "echo:%cust_pause%" & pause > nul & popd & exit'"

echo:"%cust_pause%"

pause > nul

popd