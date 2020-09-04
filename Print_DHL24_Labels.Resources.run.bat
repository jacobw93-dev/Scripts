@ECHO off
SETLOCAL ENABLEEXTENSIONS EnableDelayedExpansion
mode 100,20 > nul
chcp 65001 > nul
Title Wydruk etykiet z DHL24
SET print_config=print_config.ini
(Set LF=^
%Null%
)
SET "printout=outdir"
if not exist %printout% ( md "%printout%" )
SET "printout=%~dp0%printout%"
:init
SET lock=%temp%\~%~n0.lock > nul
8>&2 2>nul ( 2>&8 9>"!lock!" call :start ) || (
cls
ECHO:PROGRAM JEST JUŻ URUCHOMIONY
timeout /T 3 >nul
cls
)
del "!lock!" 2>nul
exit /b
:start
cd /d %~dpnx0 > nul
cls
:continue
ECHO:Wydruk etykiet ZBLP jest możliwy jedynie na drukarkach termicznych udostępnionych w sieci oraz obsługujących format ZPL.
ECHO.

if not exist "%print_config%" (
GOTO :SET_path
) else (
for /f "tokens=1,2 delims==" %%a in (%print_config%) do (
if %%a==UserInputPath SET UserInputPath=%%b
if %%a==UserPrinterPath SET UserPrinterPath=%%b
)
GOTO :almost
)
:SET_path
%SystemRoot%\System32\choice.exe /C 12 /M "Wskaż ścieżkę do katalogu, z którego chcesz wczytywać pliki:!LF!!LF![1] -> %UserProfile%\Downloads (domyślna)!LF![2] -> Okienko wyboru!LF!"!LF!
set v=@"%systemroot%\system32\mshta.exe" "javascript:var objShellApp = new ActiveXObject('Shell.Application');var Folder = objShellApp.BrowseForFolder(0, 'Wskaż folder, w którym zapisujesz pliki etykiet (BLP, LBLP, ZPL):',1, '::{20D04FE0-3AEA-1069-A2D8-08002B30309D}');try {new ActiveXObject('Scripting.FileSystemObject').GetStandardStream(1).Write(Folder.Self.Path)};catch (e){};close(); " > nul
IF ERRORLEVEL 1 SET UserInputPath=%UserProfile%\Downloads
IF ERRORLEVEL 2 (for /f "usebackq delims=" %%i in (`%v%  1^|more`) do (set UserInputPath=%%i)
IF DEFINED UserInputPath ( goto :SET_printer ) else ( echo:Folder nie został wybrany )
)
IF "%printout%"=="%UserInputPath%" (
echo:Folder źródłowy musi być inny niż docelowy!
PAUSE > NULL
goto :SET_path
)
:SET_printer
ECHO.

%SystemRoot%\System32\choice.exe /C 12 /M "Czy chcesz drukować etykiety na:!LF!!LF![1] -> drukarce termicznej!LF![2] -> na laserowej/atramentowej?"!LF!!LF!
IF ERRORLEVEL 1 ( SET "mask=etykieta*.pdf etykieta*.zpl" && set "wybor=t" ) 
IF ERRORLEVEL 2 ( SET "mask=etykieta*.pdf" && set "wybor=l" && goto :another_part )

SET i=0
SET j=0
for /f "tokens=1* delims==" %%a in ('wmic printer where "VerticalResolution=203 and Shared=True" get sharename 2^> nul ^/format:list ^| sort ^| find "="'
) do (
SET /a i+=1
if "%%a"=="ShareName" SET ShareName[!i!]=%%b
)
for /f "tokens=1* delims==" %%a in ('wmic printer where "VerticalResolution=203 and Shared=True" get systemname 2^> nul ^/format:list ^| sort ^| find "="'
) do (
SET /a j+=1
if "%%a"=="SystemName" SET SystemName[!j!]=%%b
)
IF !i! leq 0 (
echo:Brak zainstalowanej udostępnionej drukarki termicznej...
pause > nul
goto :another_part
) else (
echo.
ECHO:Dostępne drukarki termiczne na tym komputerze:
)
ECHO.~~~~~~~~~~~~
SET len=!i!
SET k=1
:unc_path
call SET Drukarka[!k!]=\\!SystemName[%k%]!\!ShareName[%k%]!
SET /a "k+=1"
if !k! leq !len! GOTO :unc_path
SET Drukarka
ECHO.~~~~~~~~~~~~
ECHO.
SET /a count=%len%
SET ph=
FOR /L %%a IN (1,1,%count%) DO SET ph=!ph!%%a
%SystemRoot%\System32\choice.exe /C Q%ph% /M "Wybierz numer ścieżki sieciowej do drukarki termicznej,!LF!lub naciśnij klawisz [Q] aby zamknąć program!LF!"!LF!
SET /A UserChoice=%ERRORLEVEL%-1
IF %UserChoice% == 0 (
ECHO:Naciśnij dowolny klawisz aby zamknąć program.
pause > nul
exit
) else (
call SET UserPrinterPath=\\%%SystemName[!UserChoice!]%%\%%ShareName[!UserChoice!]%%
)
:another_part
(ECHO:UserInputPath=!UserInputPath!^

UserPrinterPath=!UserPrinterPath!^^) > %print_config%
:almost

IF NOT "!UserPrinterPath!"==" " ( set "mask=etykieta*.pdf etykieta*.zpl" ) else ( set "mask=etykieta*.pdf" )
IF NOT "!UserPrinterPath!"=="" ( set "mask=etykieta*.pdf etykieta*.zpl" ) else ( set "mask=etykieta*.pdf" )

cls
for /f "tokens=2 delims==" %%a in ('wmic printer where "Default=TRUE" get Name /value ^| find "="') do (SET DefaultPrinter=%%a)
IF NOT "%UserPrinterPath%"=="" (for /f "tokens=2 delims=\" %%a in ("!UserPrinterPath!") do (SET ThermalPrinter=%%a
(wmic printer where "Local=FALSE and VerticalResolution=203" get Name, ShareName, Local /format:list 2> nul | findstr "!ThermalPrinter!" > nul ) && (SET ThermalPrinter=!UserPrinterPath!))
)

ECHO.
ECHO:Wybrana ścieżka: !UserInputPath!
if "!wybor!"=="t" ( call ECHO:Drukarka dla ZBLP, BLP: !UserPrinterPath! )
ECHO:Drukarka dla LBLP: !DefaultPrinter!
call ECHO:Katalog wydrukowanych etykiet: !printout!
ECHO:Plik konfiguracyjny: %~dp0%print_config%

set PDFtoPrinter=PDFtoPrinter.exe
set PDFtoPrinter=%~dp0%PDFtoPrinter%

cd /d !UserInputPath!

ECHO.
ECHO:Trwa wczytywanie plików ^(!mask!^)...
ECHO.
:LOOP
for %%i in (!mask!) do (
ECHO:Trwa drukowanie pliku: "%%i"
SET "fname=%%~nxi"
SET "fpath=%%~fi"
if "!wybor!"=="t" (
if "!fname:~-3!"=="pdf" ( %PDFtoPrinter% "!fpath!" "!UserPrinterPath!" > nul )
if "!fname:~-3!"=="zpl" ( copy "%%i" "!UserPrinterPath!" > nul )
) else ( %PDFtoPrinter% "!fpath!" > nul )
copy "!fname!" "!printout!\" > nul
del /F /Q "!fname!"
)
GOTO :LOOP