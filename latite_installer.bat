@:: Latite Appx Installer
@:: by rice#2532 and VastraKai#0001
@if not "%debug%" == "true" @echo off
setlocal EnableDelayedExpansion EnableExtensions
set LatiteDir=%userprofile%\Latite
set LatiteApp=%LatiteDir%\App
set LatiteVersion=1.19.63
set LatiteAppxUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.appx
set LatiteCertUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.cer

for /f %%a in ('copy /Z "%~dpf0" nul') do set "ASCII_13=%%a"
for /F %%C in ('copy /Z "%~f0" nul') do set "CR=%%C"
for /F %%C in ('echo prompt $H ^| cmd') do set "BS=%%C"
if "%1" == "--internal-speedmonitor" (
  set "params=%*"
  set "params=!params:--internal-speedmonitor=!"
  if "!params!" == "1" goto :EOF
  call :DownloadSpeed !params!
  goto :EOF
)

goto :checkPrivileges
:gotPrivileges

call :IsDeveloperModeEnabled
if not "%errorlevel%" == "0" ( 
    call :EnableDeveloperMode
)
if /i not "%~1" == "--uninstall" (
echo DISCLAIMER: This will replace your minecraft installation with latite client. 
echo By continuing, you are accepting that things might go wrong, and things might break. Your data shouldn't get deleted,
echo but it is always smart to make a backup.
echo Things like persona cosmetics and shaders WILL GET DELETED.
pause
)

:: Remove current Minecraft bedrock installation
taskkill /f /im Minecraft.Windows.exe >nul 2>&1
taskkill /f /im Minecraft.Windows.exe >nul 2>&1
taskkill /f /im Minecraft.Windows.exe >nul 2>&1

call :IsMinecraftInstalled
if "%errorlevel%" == "1" (
  echo Removing old Minecraft Bedrock install...
  taskkill /f /im PowerToys.PowerLauncher.exe > nul 2>&1 %=NOTE - This will NOT affect the functionality of PowerToys=%
  powershell -Command "& {Get-AppxPackage Microsoft.MinecraftUWP* | Remove-AppxPackage -PreserveRoamableApplicationData }"
)

rmdir /q /s "%LatiteApp%" > nul 2>&1
:: if the above command fails, try the below command
if exist "%LatiteApp%" powershell rmdir "%LatiteApp%" -Recurse -Force > nul 2>&1
if exist "%LatiteApp%" (
  echo Failed to remove old Latite directory. 
  pause
)
rmdir /q /s "%LatiteDir%" > nul 2>&1

:: if the above command fails, try the below command
if exist "%LatiteDir%" powershell rmdir "%LatiteDir%" -Recurse -Force > nul 2>&1
if /i "%~1" == "--uninstall" (
  echo Latite has been uninstalled.
  goto :EOF
)

md "%LatiteDir%"
md "%LatiteApp%"



:: Download appx
echo Downloading Latite %LatiteVersion%...
call :DownloadFile "%LatiteAppxUrl%" "%LatiteDir%\latite.appx"

:: Download and add certificate
echo Adding certificate...
call :DownloadFile "%LatiteCertUrl%" "%LatiteDir%\latite.cer"
certutil -addstore -enterprise -f -v root "%LatiteDir%\latite.cer" > nul



echo Checking for dependencies...
powershell Get-AppxPackage Microsoft.Services.Store.Engagement* | findstr /I /C:"x64" > nul 2>&1
if not "%errorlevel%" == "0" (
  echo Downloading Microsoft.Services.Store.Engagement.x64.appx...
  call :DownloadFile "https://vastrakai.wtf/downloads/Microsoft.Services.Store.Engagement.x64.appx" "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx"
  echo Installing...
  powershell Add-AppPackage "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" -ForceApplicationShutdown
)
powershell Get-AppxPackage Microsoft.VCLibs* | findstr /I /C:"x64" > nul 2>&1
if not "%errorlevel%" == "0" (
  echo Downloading Microsoft.VCLibs.x64.appx...
  call :DownloadFile "https://vastrakai.wtf/downloads/Microsoft.VCLibs.x64.appx" "%LatiteDir%\Microsoft.VCLibs.x64.appx"
  echo Installing...
  powershell Add-AppPackage "%LatiteDir%\Microsoft.VCLibs.x64.appx" -ForceApplicationShutdown
)
call :IsRedistInstalled
if not "%errorlevel%" == "0" (
  echo Downloading vc_redist.x64.exe...
  call :DownloadFile "https://aka.ms/vs/17/release/vc_redist.x64.exe" "%LatiteDir%\vc_redist.x64.exe"
  echo Installing...
  "%LatiteDir%\vc_redist.x64.exe" /install /quiet /norestart
)
:trydelete
del /f /q "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\Microsoft.VCLibs.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\vc_redist.x64.exe" > nul 2>&1
if exist "%LatiteDir%\vc_redist.x64.exe" goto :trydelete



:: Extract appx
echo Extracting appx...
call :UnzipFile "%LatiteDir%\latite.appx" "%LatiteApp%"
echo Registering appx...
powershell Add-AppxPackage -Path "%LatiteApp%\AppxManifest.xml" -Register
if "%errorlevel%" == "0" (
  echo Latite has been installed^^!
  start "" minecraft:
  del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
  del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
  pause
  goto :EOF
) 
echo Failed to register extracted appx, falling back to directly registering appx.
rmdir /s /q "%LatiteApp%" > nul
echo Registering appx...
powershell Add-AppxPackage -Path "%LatiteDir%\Latite.appx"
if "%errorlevel%" == "0" (
  echo Latite has been installed^^!
  start "" minecraft:
  del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
  del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
  pause
  goto :EOF
)
echo Failed to auto-install Latite.
echo Please follow the instructions on the pop up window.
echo When the installation is complete, press any key to continue.
start "" "%LatiteDir%\Latite.appx"
call :IsMinecraftInstalled
if "%errorlevel%" == "0" (
  del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
  del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
  start "" minecraft:
  echo Latite has been installed^^!
  pause
  goto :EOF
)
echo Install failed!
goto :EOF

:: ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~- Utils

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

:formatSizeD <number> <outputVar> <includeSuffix>
set "number=%1"
set "result=%number%"
set "suffix="
set timesDivided=0
set varName=%~2

:formatUntilDone2
call :evalVbs Round^^(%result%^^)
if %output% LSS 1000 goto :done2
call :evalVbs %result% / 1000
set result=%output%
set /a timesDivided=%timesDivided% + 1
goto :formatUntilDone2

:done2
:: the suffix should be based on how many times we divided by 1000
if "%~3" == "1" (
  if "%timesDivided%" == "0" set "suffix= B"
  if "%timesDivided%" == "1" set "suffix= KB"
  if "%timesDivided%" == "2" set "suffix= MB"
  if "%timesDivided%" == "3" set "suffix= GB"
)
set "result=%result%%suffix%"
set "!varName!=%result%"
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

:DownloadSpeed <logPath> <sourceUrl> <targetLocation>
set sourceUrl=%~2
set targetLocation=%~3
call :GetContentLength "%sourceUrl%"
set targetSize=%size%
set size=0
@REM echo.Params: '%*'
@REM echo sourceUrl: '%sourceUrl%'
@REM echo targetLocation: '%targetLocation%'
@REM echo targetSize: '%targetSize%'
@REM echo size: '%size%'
set currentSize=0
:waitForDownload2
set size=%~z3
set /a bytesDownloaded=%size%-%currentSize%
set "currentSize=%size%"
if not defined currentSize set "currentSize=0"
@REM if "%currentSize%" == "0" (
@REM     set "percent=0"
@REM ) else (
@REM     call :calculatePercent %currentSize% %targetSize%
@REM )
@REM call :getProgressBarString %percent%
@REM if not "%oldStr%" == "%progressBarString%" call :iecho %progressBarString%
call :formatSizeD %bytesDownloaded% downSpeed 1
::call :iEcho Download speed: %downSpeed%/s, %currentSize%/%targetSize% bytes
>"%~1" echo.%downSpeed%
timeout -t 1 -nobreak > nul 2>&1

if "%currentSize%" == "%targetSize%" goto :downloadFinished2
goto :waitForDownload2
:downloadFinished2
exit

:TryGetDownloadSpeed <logPath>
set "logPath=%~1"
if not exist "%logPath%" (
  set downSpeed=0 
  exit /b
)
for /f "tokens=*" %%i in ('type %logPath%') do (
  if not "%%i" == "" set "downSpeed=%%i"
)
if not defined downSpeed set downSpeed=0
exit /b

:DownloadFile <sourceUrl> <targetLocation>
set downSpeed=0
set sourceUrl=%~1
set targetLocation=%~2
call :GetContentLength "%sourceUrl%"
set targetSize=%size%
set size=0
start /b "" cmd /c %~s0 --internal-speedmonitor "%temp%\DownSpeed.tmp" "%sourceUrl%" "%targetLocation%"
start /b "" powershell -command "(New-Object System.Net.WebClient).DownloadFile(\"%sourceUrl%\", \"%targetLocation%\") "

:waitForDownload
set currentSize=0
call :size "%targetLocation%"
set "currentSize=%size%"
if not defined currentSize set "currentSize=0"
if "%currentSize%" == "0" (
    set "percent=0"
) else (
    call :calculatePercent %currentSize% %targetSize% 1
)
call :getProgressBarString %percent%
if not "%oldStr%" == "%progressBarString%" call :iecho %progressBarString%
if "%currentSize%" == "%targetSize%" goto :downloadFinished
call :Delay 100
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
call :evalVbs Round^^(%percent%^^)
set "roundedPercent=%output%"
set /a percentPerBar=100 / %progressBarLength%
set /a bars=%roundedPercent% / %percentPerBar%
set /a targetBars=%roundedPercent% / %percentPerBar%
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
set progressBarString=%barsString%%spacesString%
set percentString=%percent%%%%%
:: -- Place the percent in the middle of the progressBarString
:: Get the length of the progressBarString  
call :strlen progressBarString progressBarStringLength
:: Get the length of the percent
call :strlen percentString percentStringLength
:: Get the length of the progressBarString minus half the length of the percent
set /a progressPosition=%progressBarStringLength% / 2
set "progressBarStringLeft=!progressBarString:~0,%progressPosition%!"
set "progressBarStringRight=!progressBarString:~%progressPosition%!"

set /a percentStringLength=%percentStringLength% / 2
set "progressBarStringLeft=!progressBarStringLeft:~0,-%percentStringLength%!"
set "progressBarStringRight=!progressBarStringRight:~%percentStringLength%!"
:: Rebuild the progressBarString
set "progressBarString=%progressBarStringLeft%%percentString%%progressBarStringRight%"
:: -- Place the percent in the middle of the progressBarString
call :TryGetDownloadSpeed "%temp%\DownSpeed.tmp"
set "progressBarString=[%progressBarString%] (%downSpeed%/s) "%=why is this necessary=%
exit /b

:calculatePercent <current> <total> <decimals>
set "current=%1"
set "total=%2"
set "decimals=%3"
if not exist "%temp%\calculatePercent.vbs" echo wscript.echo(Round(Wscript.Arguments(0) / Wscript.Arguments(1) * 100, Wscript.Arguments(2))) > "%temp%\calculatePercent.vbs"
for /f "tokens=*" %%i in ('cscript //nologo "%temp%\calculatePercent.vbs" %current% %total% %decimals%') do set "percent=%%i"
exit /b

 
:strLen
setlocal enabledelayedexpansion
:strLen_Loop
  if not "!%1:~%len%!"=="" set /A len+=1 & goto :strLen_Loop
(endlocal & set %2=%len%)
goto :eof


:evalVbs <code>
if not exist "%temp%\eval.vbs" (
  > "%temp%\eval.vbs" echo ReDim arr^(WScript.Arguments.Count-1^)
  >> "%temp%\eval.vbs" echo For i = 0 To WScript.Arguments.Count-1
  >> "%temp%\eval.vbs" echo   arr^(i^) = WScript.Arguments^(i^)
  >> "%temp%\eval.vbs" echo Next
  >> "%temp%\eval.vbs" echo.
  >> "%temp%\eval.vbs" echo WScript.Echo^(Eval^(Join^(arr^)^)^)
)
::echo.%*
for /f "tokens=*" %%i in ('cscript //nologo "%temp%\eval.vbs" %*') do set "output=%%i"

exit /b

:IsMinecraftInstalled
powershell Get-AppxPackage Microsoft.MinecraftUWP* | findstr /i /c:"microsoft.minecraftuwp" > nul 2>&1
exit /b %errorlevel%

:IsRedistInstalled
reg query HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\ >nul 2>&1
exit /b %errorlevel%

:IsDeveloperModeEnabled
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock /v AllowDevelopmentWithoutDevLicense 2>nul | findstr /I /C:"0x1" > nul 2>&1
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
set "STRING=%*"
set "SPACCCES=                                                                             "
::set /P ="%BS%!CR!%SPACES%!CR!" < nul
set /p <nul =%BS%!CR!%SPACCCES%!CR!%STRING%
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

:Delay <milliseconds>
setlocal enableextensions
set /a correct=0
set /a msecs=%1+5
if /i %msecs% leq 20 set /a correct-=2
set time1=%time: =%
set /a tsecs=%1/1000 2>nul
set /a msecs=(%msecs% %% 1000)/10
for /f "tokens=1-4 delims=:." %%a in ("%time1%") do (
  set hour1=%%a&set min1=%%b&set sec1=%%c&set "mil1=%%d"
)
if /i %hour1:~0,1% equ 0 if /i "%hour1:~1%" neq "" set hour1=%hour1:~1% 
if /i %min1:~0,1% equ 0 set min1=%min1:~1% 
if /i %sec1:~0,1% equ 0 set sec1=%sec1:~1%
if /i %mil1:~0,1% equ 0 set mil1=%mil1:~1% 
set /a sec1+=(%hour1%*3600)+(%min1%*60)
set /a msecs+=%mil1%
set /a tsecs+=(%sec1%+%msecs%/100)
set /a msecs=%msecs% %% 100
::    check for midnight crossing
if /i %tsecs% geq 86400 set /a tsecs-=86400
set /a hour2=%tsecs% / 3600
set /a min2=(%tsecs%-(%hour2%*3600)) / 60
set /a sec2=(%tsecs%-(%hour2%*3600)) %% 60
set /a err=%msecs%
if /i %msecs% neq 0 set /a msecs+=%correct%
if /i 1%msecs% lss 20 set msecs=0%msecs%
if /i 1%min2% lss 20 set min2=0%min2%
if /i 1%sec2% lss 20 set sec2=0%sec2%
set time2=%hour2%:%min2%:%sec2%.%msecs%
:wait
  set timen=%time: =%
  if /i %timen% geq %time2% goto :end
goto :wait
:end
for /f "tokens=2 delims=." %%a in ("%timen%") do set num=%%a
if /i %num:~0,1% equ 0 set num=%num:~1%
set /a err=(%num%-%err%)*10
endlocal&exit /b %err%