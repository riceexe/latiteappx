@echo off
set LatiteDir=%userprofile%\Latite
set LatiteApp=%LatiteDir%\App
set LatiteVersion=1.19.63
set LatiteAppxUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.appx
set LatiteCertUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.cer
for /f %%a in ('copy /Z "%~dpf0" nul') do set "ASCII_13=%%a"
for /F %%C in ('copy /Z "%~f0" nul') do set "CR=%%C"
for /F %%C in ('echo prompt $H ^| cmd') do set "BS=%%C"

goto :checkPrivileges
:gotPrivileges

call :IsDeveloperModeEnabled
if "%errorlevel%" == "0" ( 
    echo Developer mode is enabled. 
) else ( 
    call :EnableDeveloperMode
)

echo DISCLAIMER: This will replace your minecraft installation with latite client. 
echo By continuing, you are accepting that things might go wrong, and things might break. Your data shouldn't get deleted,
echo but it is always smart to make a backup.
echo Things like persona cosmetics and shaders WILL GET DELETED.
pause

:: Remove current Minecraft bedrock installation
taskkill /f /im Minecraft.Windows.exe >nul 2>&1

call :IsMinecraftInstalled
if "%errorlevel%" == "1" (
  echo Removing old Minecraft Bedrock install...
  powershell -Command "& {Get-AppxPackage Microsoft.MinecraftUWP* | Remove-AppxPackage -PreserveRoamableApplicationData }"
)

rmdir /q /s "%LatiteApp%" > nul 2>&1
:: if the above command fails, try the below command
if exist "%LatiteApp%" powershell rmdir "%LatiteApp%" -Recurse -Force > nul 2>&1
if exist "%LatiteApp%" (
  echo Failed to remove old Latite directory. If you have powertoys installed, try exiting it. 
  pause
)
rmdir /q /s "%LatiteDir%" > nul 2>&1

:: if the above command fails, try the below command
if exist "%LatiteDir%" powershell rmdir "%LatiteDir%" -Recurse -Force > nul 2>&1
if "%~1" == "--uninstall" (
  echo Latite has been uninstalled.
  goto :EOF
)

md "%LatiteDir%"
md "%LatiteApp%"

:: Download appx
echo Downloading appx... 

::powershell -command "& {Start-BitsTransfer -DisplayName "Downloading..." -Source "%LatiteAppxUrl%" -Destination "%LatiteDir%\latite.appx"}"
call :DownloadFile "%LatiteAppxUrl%" "%LatiteDir%\latite.appx"
:: Download and add certificate
echo Adding cert...

::powershell -command "& {Start-BitsTransfer -DisplayName "Downloading..." -Source "%LatiteCertUrl%" -Destination "%LatiteDir%\latite.cer"}"
call :DownloadFile "%LatiteCertUrl%" "%LatiteDir%\latite.cer"
certutil -addstore -enterprise -f -v root "%LatiteDir%\latite.cer" > nul

:: Extract appx
echo Extracting appx...
call :UnzipFile "%LatiteDir%\latite.appx" "%LatiteApp%"
::powershell -command "& {Expand-Archive -Path "%LatiteDir%\Latite.zip" -DestinationPath "%LatiteApp% -Force"}"
::call :UnzipFile "%LatiteDir%\Latite.zip" "%LatiteApp%"
echo Registering appx...

powershell Add-AppxPackage -Path "%LatiteApp%\AppxManifest.xml" -Register
if "%errorlevel%" == "0" (
  echo Latite has been installed!
  start "" minecraft:
) else (
  echo Failed to register extracted appx, falling back to directly registering appx.
  call :AppxFallback
)
del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
pause
goto :EOF

:AppxFallback
rmdir /s /q "%LatiteApp%" > nul
echo Registering appx...
powershell Add-AppxPackage -Path "%LatiteDir%\Latite.appx"
if "%errorlevel%" == "0" (
  echo Latite has been installed!
  start "" minecraft:
) else (
  echo Failed to auto-install Latite.
  echo Please follow the instructions on the pop up window.
  echo When you're finished, click this window and press a key.
  start "" "%LatiteDir%\Latite.appx"
  pause > nul
  start "" minecraft:
)
goto :EOF

:: ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~- Utils

:: This will be like 100x faster than any other method but it won't show progress
:GetContentLength <url>
for /f "tokens=*" %%i in ('powershell -command "& { Add-Type -AssemblyName System.Net.Http; (New-Object System.Net.Http.HttpClient).SendAsync([System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod] 'Head', '%~1')).Result.Content.Headers.ContentLength }"') do set size=%%i
exit /b

:formatSize <number> <includeSuffix>
set "number=%1"
set "newSize=%number%"
set "suffix="
set timesDivided=0
:formatUntilDone
:: if the number is less than 1000, we are done
if %newSize% LSS 1000 goto :done
:: otherwise, divide by 1000 and try again
set /a newSize=%newSize% / 1000
set /a timesDivided=%timesDivided% + 1
goto :formatUntilDone

:done
:: the suffix should be based on how many times we divided by 1000
if "%~2" == "1" (
  if "%timesDivided%" == "0" set "suffix= B"
  if "%timesDivided%" == "1" set "suffix= KB"
  if "%timesDivided%" == "2" set "suffix= MB"
  if "%timesDivided%" == "3" set "suffix= GB"
)
set "newSize=%newSize%%suffix%"
exit /b

:size <file>
@REM if not defined oldsize set oldsize=0
@REM if not "%oldsize%" == "%~z1%" (
@REM     call :formatSize %~z1
@REM     call :iecho %size% downloaded so far
@REM )
@REM set oldsize=%~z1
set size=%~z1
exit /b



:DownloadFile <sourceUrl> <targetLocation>
set sourceUrl=%~1
set targetLocation=%~2
call :GetContentLength "%sourceUrl%"
set targetSize=%size%
set size=0
start /b "" powershell -command "(New-Object System.Net.WebClient).DownloadFile(\"%sourceUrl%\", \"%targetLocation%\") "
:waitForDownload
set currentSize=0
call :size "%targetLocation%"
set "currentSize=%size%"
if not defined currentSize set "currentSize=0"
if "%currentSize%" == "0" (
    set "percent=0"
) else (
    call :calulatePercent %currentSize% %targetSize%
)
call :getProgressBarString %percent%
if not "%oldStr%" == "%progressBarString%" call :iecho %progressBarString%
if "%currentSize%" == "%targetSize%" goto :downloadFinished
goto :waitForDownload
:downloadFinished
echo.
exit /b

:getProgressBarString <percent>
if defined oldPercent if "%oldPercent%" == "%percent%" exit /b
set oldPercent=%percent%
set "progressBarString="
set "barsString="
set "progressBarLength=50"
set "barChar=="
set /a percentPerBar=100 / %progressBarLength%
set /a bars=%percent% / %percentPerBar%
set /a targetBars=%percent% / %percentPerBar%
:: append the barChar to the progressBarString for each bar
:appendBarChar
if %bars% LSS 1 goto :doneAppending
set "barsString=%barsString%%barChar%"
set /a bars=%bars% - 1
goto :appendBarChar
:doneAppending
set /a spaces=%progressBarLength% - %targetBars%
set "spacesString="
:appendSpaceChar
if %spaces% LSS 1 goto :doneAppendingSpaces
set "spacesString=%spacesString% "
set /a spaces=%spaces% - 1
goto :appendSpaceChar
:doneAppendingSpaces
set "progressBarString=[%barsString%%spacesString%] %percent%%%%%"%=why is this necessary=%
exit /b

:calulatePercent <current> <total>
set "current=%1"
set "total=%2"
:: cmd set /a does not support floating point numbers
:: so we have to do it manually
if not exist "%temp%\calulatePercent.vbs" echo wscript.echo(Round(Wscript.Arguments(0) / Wscript.Arguments(1)* 100)) > "%temp%\calulatePercent.vbs"
for /f "tokens=*" %%i in ('cscript //nologo "%temp%\calulatePercent.vbs" %current% %total%') do set "percent=%%i"
::del /f /q "%temp%\test.vbs" > nul 2>&1
exit /b

:IsDeveloperModeEnabled
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock /v AllowDevelopmentWithoutDevLicense | findstr /I /C:"0x1" > nul 2>&1
exit /b %errorlevel%

:EnableDeveloperMode
call :iecho Enabling developer mode...
set code=0
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f > nul
set /a code=%code% + %errorlevel%
DISM /Online /Add-Capability /CapabilityName:Tools.DeveloperMode.Core~~~~0.0.1.0 > nul
set /a code=%code% + %errorlevel%
if "%code%" == "0" ( 
    call :iecho Developer mode has been enabled.
    echo.
) else (
    call :iecho Failed to enable developer mode!
    echo.
    exit /b 1
)
exit /b

:checkPrivileges
net file 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )
goto :getPrivileges

:getPrivileges
echo.
echo =-=-=-=-=-=-=-=-=-=-=-=-=
echo Waiting for elevation...
echo =-=-=-=-=-=-=-=-=-=-=-=-=
taskkill /f /im waitfor.exe > nul 2>&1

:: short file names are required here, if you don't use them you will get errors with spaces
powershell.exe Start-Process cmd.exe -Verb RunAs -ArgumentList '/c "%~s0"'
if not "%errorlevel%" == "0" (
    :: Todo: Add backup elevation using vbscript
    echo Error: Elevation failed ^(%errorlevel%^). Please report this!
    echo Press any key to exit...
    pause > nul
    goto :EOF
)
exit /b

:iecho <string>
setlocal EnableDelayedExpansion
for /f %%a in ('copy /Z "%~dpf0" nul') do set "ASCII_13=%%a"
for /F %%C in ('copy /Z "%~f0" nul') do set "CR=%%C"
for /F %%C in ('echo prompt $H ^| cmd') do set "BS=%%C"
set "STRING=%*"
set "SPACES=                                      "
set /P ="%BS%!CR!%SPACES%!CR!" < nul
set /p <nul =%STRING%
exit /B

:IsMinecraftInstalled
set Installed=0
for /f "tokens=*" %%a in ('powershell Get-AppxPackage Microsoft.MinecraftUWP*') do set Installed=1
exit /b %Installed%

:UnzipFile <ZipFile> <ExtractTo> 
call :Install7ZModule
powershell Expand-7Zip -ArchiveFileName "%~1" -TargetPath "%~2"
exit /b

:: fuck you powershell 7z on top
:Install7ZModule
powershell get-module -All -ListAvailable | findstr /i /c:"7zip4powershell" > nul 2>&1 && exit /b
> nul 2>&1 powershell Install-PackageProvider NuGet -Force; Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module -Name 7Zip4Powershell -Force
exit /b