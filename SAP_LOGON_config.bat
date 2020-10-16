@echo off
cmd /c
NET USE * /delete /y > nul
popd
cls
pushd %~dp0

SETLOCAL ENABLEEXTENSIONS EnableDelayedExpansion
mode 100,20 > nul
chcp 65001 > nul

set "cust_pause=Naciśnij [Spacja] lub [Enter] aby kontynuować..."

echo:Utworzenie wpisu w rejestrze na podstawie pliku %CD%\SAPSecureLogin.reg
%windir%\System32\reg.exe import %CD%\SAPSecureLogin.reg
echo:"%cust_pause%"
pause > nul

echo.
echo:Kopiowanie pliku "%CD%\SAPLOGON.ini" do "%programfiles(x86)%\sap\SAPLOGON_INI\*.*"
copy /Y "%CD%\SAPLOGON.ini" "%programfiles(x86)%\sap\SAPLOGON_INI\*.*"
echo:"%cust_pause%"
pause > nul

echo.
echo:Kopiowanie pliku "%CD%\Ao_user_roaming.config" do "%appdata%\SAP\Cof\*.*"
copy /Y "%CD%\Ao_user_roaming.config" "%appdata%\SAP\Cof\*.*"
echo:"%cust_pause%"
pause > nul

echo.
powershell -Command "Start-Process 'cmd' -Verb RunAs -ArgumentList '/s /k "echo:Kopiowanie pliku %CD%\SAPLOGON.ini do %WINDIR%\*.*" & "copy /Y " "%CD%\SAPLOGON.ini" " " "%WINDIR%\*.*" & "echo:%cust_pause%" & pause > nul & popd & exit'"
echo:"Naciśnij [Spacja] lub [Enter] aby zakończyć"
pause > nul
popd

