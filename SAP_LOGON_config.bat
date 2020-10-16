@echo off
cmd /c
popd
cls
NET USE * /delete /y > nul
pushd %~dp0
SETLOCAL ENABLEEXTENSIONS EnableDelayedExpansion
mode 100,20 > nul
chcp 65001 > nul
(Set LF=^
%Null%
)
set "currentpath=%CD%"
set "NETPATH=%~dp0"
%SystemRoot%\System32\choice.exe /C:12 /M "Czy uruchamiasz skrypt: !LF![1] z zasobu lokalnego !LF![2] czy z sieciowego ? :!LF!!LF!"%1
IF ERRORLEVEL ==1 GOTO :local
IF ERRORLEVEL ==2 GOTO :network

:local
powershell -Command "Start-Process 'cmd' -Verb RunAs -ArgumentList '/s /c "echo:Kopiowanie pliku %CD%\SAPLOGON.ini do %WINDIR%\*.*" & "copy /Y " "%CD%\SAPLOGON.ini" " " "%WINDIR%\*.*" & "echo:Naciśnij [Spacja] lub [Enter] aby kontynuować..." & pause > nul & exit'"
goto :CONTINUE

:network
pushd %NETPATH%
set "currentpath=%CD%"
powershell -Command "Start-Process 'cmd' -Verb RunAs -ArgumentList '/s /c "pushd %~dp0" & "pushd %NETPATH%" & "echo:Kopiowanie pliku %CD%\SAPLOGON.ini do %WINDIR%\*.*" & "copy /Y " "%CD%\SAPLOGON.ini" " " "%WINDIR%\*.*" & "echo:Naciśnij [Spacja] lub [Enter] aby kontynuować..." & pause > nul & popd & exit'"
goto :CONTINUE

:CONTINUE
echo.
echo:"Naciśnij [Spacja] lub [Enter] aby kontynuować..."
pause > nul
echo.
echo:Utworzenie wpisu w rejestrze na podstawie pliku %currentpath%\SAPSecureLogin.reg
%windir%\System32\reg.exe import %currentpath%\SAPSecureLogin.reg
echo:"Naciśnij [Spacja] lub [Enter] aby kontynuować..."
pause > nul
echo.
echo:Kopiowanie pliku "%currentpath%\SAPLOGON.ini" do "%programfiles(x86)%\sap\SAPLOGON_INI\*.*"
copy /Y "%currentpath%\SAPLOGON.ini" "%programfiles(x86)%\sap\SAPLOGON_INI\*.*"
echo:"Naciśnij [Spacja] lub [Enter] aby kontynuować..."
pause > nul
echo.
echo:Kopiowanie pliku "%currentpath%\Ao_user_roaming.config" do "%appdata%\SAP\Cof\*.*"
copy /Y "%currentpath%\Ao_user_roaming.config" "%appdata%\SAP\Cof\*.*"
echo:"Naciśnij [Spacja] lub [Enter] aby kontynuować..."
pause > nul
popd

