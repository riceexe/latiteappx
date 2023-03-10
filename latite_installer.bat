@:: Latite Appx Installer
@:: by rice#2532 and VastraKai#0001
@if not "%debug%" == "true" @echo off 
setlocal EnableDelayedExpansion EnableExtensions

:: so the formatting doesn't go all weird when the console outputs a unicode character
> %temp%\tmp.reg echo Windows Registry Editor Version 5.00
>> %temp%\tmp.reg echo.
>> %temp%\tmp.reg echo [HKEY_CURRENT_USER\Console\%%SystemRoot%%_system32_cmd.exe]
>> %temp%\tmp.reg echo "ScreenBufferSize"=dword:23290000
>> %temp%\tmp.reg echo "WindowSize"=dword:003600bd
>> %temp%\tmp.reg echo "FontFamily"=dword:00000036
>> %temp%\tmp.reg echo "FontWeight"=dword:00000190
>> %temp%\tmp.reg echo "FaceName"="Lucida Console"
>> %temp%\tmp.reg echo "CursorType"=dword:00000000
>> %temp%\tmp.reg echo "InterceptCopyPaste"=dword:00000000
:: check if there the registry key exists
reg query HKEY_CURRENT_USER\Console\%SystemRoot%_system32_cmd.exe > nul 2>&1
if not "%errorlevel%" == "0" reg import %temp%\tmp.reg > nul 2>&1
del /f /q %temp%\tmp.reg > nul 2>&1

chcp 65001 > nul
set LatiteDir=%userprofile%\Latite
set LatiteApp=%LatiteDir%\App
set LatiteVersion=1.19.63
set LatiteAppxUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.appx
set LatiteCertUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.cer
set "currentFile=%~0"
if not defined ASCII_13 for /f %%a in ('copy /Z "%~dpf0" nul') do set "ASCII_13=%%a"
if not defined CR for /F %%C in ('copy /Z "%~f0" nul') do set "CR=%%C"
if not defined BS for /F %%C in ('echo prompt $H ^| cmd') do set "BS=%%C"

if "%1" == "--internal-speedmonitor" (
  set "params=%*"
  set "params=!params:--internal-speedmonitor =!"
  set "params=!params:--internal-speedmonitor=!"
  if "!params!" == "1" goto :EOF
  call :DownloadSpeed !params!
  goto :EOF
) else if "%1" == "--internal" (
  set params=%*
  set "params=!params:%1 =!"
  set "params=!params:%1=!"
  set "params=!params:%2 =!"
  set "params=!params:%2=!"
  call :%2 !params!
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

call :RunCmdWithLoading "Removing current Minecraft installation..." call :RemoveOldMcStuff

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


echo Checking dependencies (1/3)...
powershell Get-AppxPackage Microsoft.Services.Store.Engagement* | findstr /I /C:"x64" > nul 2>&1
if not "%errorlevel%" == "0" (
  echo Downloading Microsoft.Services.Store.Engagement.x64.appx...
  call :DownloadFile "https://vastrakai.wtf/downloads/Microsoft.Services.Store.Engagement.x64.appx" "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx"
  call :RunCmdWithLoading "Installing Microsoft.Services.Store.Engagement.x64..." powershell Add-AppPackage "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" -ForceApplicationShutdown
)
echo Checking dependencies (2/3)...
powershell Get-AppxPackage Microsoft.VCLibs* | findstr /I /C:"x64" > nul 2>&1
if not "%errorlevel%" == "0" (
  echo Downloading Microsoft.VCLibs.x64.appx...
  call :DownloadFile "https://vastrakai.wtf/downloads/Microsoft.VCLibs.x64.appx" "%LatiteDir%\Microsoft.VCLibs.x64.appx"
  call :RunCmdWithLoading "Installing Microsoft.VCLibs.x64..." powershell Add-AppPackage "%LatiteDir%\Microsoft.VCLibs.x64.appx" -ForceApplicationShutdown
)
echo Checking dependencies (3/3)...
call :IsRedistInstalled
if not "%errorlevel%" == "0" (
  echo Downloading vc_redist.x64.exe...
  call :DownloadFile "https://aka.ms/vs/17/release/vc_redist.x64.exe" "%LatiteDir%\vc_redist.x64.exe"
  call :RunCmdWithLoading "Installing Visual C++ Redistributable x64..." "%LatiteDir%\vc_redist.x64.exe" /install /quiet /norestart
)
:trydelete
del /f /q "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\Microsoft.VCLibs.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\vc_redist.x64.exe" > nul 2>&1
if exist "%LatiteDir%\vc_redist.x64.exe" goto :trydelete
echo Dependencies installed.
call :RunCmdWithLoading "Extracting appx to %LatiteApp%..." call :UnzipFile "%LatiteDir%\latite.appx" "%LatiteApp%"
 
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
pause
call :IsMinecraftInstalled
if "%errorlevel%" == "0" (
  del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
  del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
  start "" minecraft:
  echo Latite has been installed^^!
  pause
  goto :EOF
)
echo Install failed^^!
pause
goto :EOF

:: ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~- Utils

:printTime
setlocal
for /f "tokens=1-4 delims=:.," %%a in ("%t0: =0%") do set /a "t0=(((1%%a*60)+1%%b)*60+1%%c)*100+1%%d-36610100
for /f "tokens=1-4 delims=:.," %%a in ("%t1: =0%") do set /a "t1=(((1%%a*60)+1%%b)*60+1%%c)*100+1%%d-36610100
set /a tm=t1-t0
if %tm% lss 0 set /a tm+=24*60*60*100
echo %tm:~0,-2%.%tm:~-2% msec
exit /b

:RunCmdWithLoading <message> <command> 
set num=0
set "loadingLog=%temp%\"
call :randomString 40 rndFile
set "loadingLog=%loadingLog%LTI_%rndFile%.tmp"
> "%loadingLog%" echo.1
set command=%*
set command=!command:%1 =!
set command=!command:%1=!
start /b "" cmd /c %currentFile% --internal LoadLog "%loadingLog%" "%~1"
%command%
> "%loadingLog%" echo.0
timeout -t 1 -nobreak > nul 2>&1
exit /b

:GetContentLength <url>
for /f "tokens=*" %%i in ('powershell -command "& { Add-Type -AssemblyName System.Net.Http; (New-Object System.Net.Http.HttpClient).SendAsync([System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod] 'Head', '%~1')).Result.Content.Headers.ContentLength }"') do set size=%%i
exit /b

:RemoveOldMcStuff
call :IsMinecraftInstalled
if "%errorlevel%" == "1" (
  taskkill /f /im PowerToys.PowerLauncher.exe > nul 2>&1 %=NOTE - This will NOT affect the functionality of PowerToys=%
  powershell -Command "& {Get-AppxPackage Microsoft.MinecraftUWP* | Remove-AppxPackage -PreserveRoamableApplicationData }"
)
rmdir /q /s "%LatiteApp%" > nul 2>&1
:: if the above command fails, try the below command
if exist "%LatiteApp%" powershell rmdir "%LatiteApp%" -Recurse -Force > nul 2>&1
rmdir /q /s "%LatiteDir%" > nul 2>&1

:: if the above command fails, try the below command
if exist "%LatiteDir%" powershell rmdir "%LatiteDir%" -Recurse -Force > nul 2>&1
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
set size=%~z1
exit /b

:DownloadSpeed <logPath> <sourceUrl> <targetLocation>
set sourceUrl=%~2
set targetLocation=%~3
call :GetContentLength "%sourceUrl%"
set targetSize=%size%
set size=0
set currentSize=0

:waitForDownload2
set size=%~z3
set /a bytesDownloaded=%size%-%currentSize%
set "currentSize=%size%"
if not defined currentSize set "currentSize=0"
call :formatSizeD %bytesDownloaded% downSpeed 1
if exist "%~1" (
>"%~1" echo.%downSpeed%
) else (
  goto :downloadFinished2
)
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
< "%logPath%" (set /p downSpeed=)
if not defined downSpeed set downSpeed=0
exit /b

:DownloadFile <sourceUrl> <targetLocation>
set downSpeed=0
set sourceUrl=%~1
set targetLocation=%~2
call :GetContentLength "%sourceUrl%"
set targetSize=%size%
set size=0
set tmpfile="%temp%\%random%%random%%random%%random%%random%%random%.tmp"
echo.0 B>"%tmpfile%"
start /b "" cmd /c %~s0 --internal-speedmonitor %tmpfile% "%sourceUrl%" "%targetLocation%"
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
call :getProgressBarString %percent% %tmpfile%
call :iecho %progressBarString%
if "%currentSize%" == "%targetSize%" goto :downloadFinished
::call :Delay 100
goto :waitForDownload
:downloadFinished
del /f /q "%tmpfile%" > nul 2>&1
echo.
exit /b

:getProgressBarString <percent> <logPath>
::if defined oldPercent if "%oldPercent%" == "%percent%" exit /b
set oldPercent=%percent%
set "progressBarString="
set "barsString="
set "spacesString=                                                  "
set "progressBarLength=50"
set "barChar=="
call :evalVbs Round^^(%percent%^^)
set "roundedPercent=%output%"
set /a percentPerBar=100 / %progressBarLength%
set /a bars=%roundedPercent% / %percentPerBar%
set /a targetBars=%roundedPercent% / %percentPerBar%

:appendBarChar
if %bars% LSS 1 goto :doneAppending
set "barsString=%barsString%%barChar%"
set /a bars=%bars% - 1
goto :appendBarChar
:doneAppending
set /a spaces=%progressBarLength% - %targetBars%
set "spacesString=!spacesString:~0,%spaces%!"
if "%percent%" == "100" set "spacesString="
call :strlen spacesString spacesStringLength
call :strlen barsString barsStringLength
set /a spacesStringLength=%progressBarLength% - %barsStringLength%
if not %spacesStringLength% == 0 set "spacesString=!spacesString:~0,%spacesStringLength%!"
set progressBarString=%barsString%%spacesString%
set percentString=%percent%•
call :strlen percentString percentStringLength
set /a progressPosition=50 / 2
set "progressBarStringLeft=!progressBarString:~0,%progressPosition%!"
set "progressBarStringRight=!progressBarString:~%progressPosition%!"
set /a percentStringLength=%percentStringLength% / 2
set "progressBarStringLeft=!progressBarStringLeft:~0,-%percentStringLength%!"
set "progressBarStringRight=!progressBarStringRight:~%percentStringLength%!"
set "progressBarString=%progressBarStringLeft%%percentString%%progressBarStringRight%"
:FixProgressBarString
call :strlen progressBarString progressBarStringLengthP
if %progressBarStringLengthP% GTR %progressBarLength% (
  set "progressBarString=%progressBarString:~0,-1%"
  goto :FixProgressBarString
) else if %progressBarStringLengthP% LSS %progressBarLength% (
  set "progressBarString=%progressBarString% "
  goto :FixProgressBarString
)
call :TryGetDownloadSpeed "%~2"
set "progressBarString=[%progressBarString%] (%downSpeed%/s) "%=why is this necessary=%
exit /b
:calculatePercent <current> <total> <decimals>
set "current=%1"
set "total=%2"
set "decimals=%3"
if not exist "%temp%\calculatePercent.vbs" echo wscript.echo(Round(Wscript.Arguments(0) / Wscript.Arguments(1) * 100, Wscript.Arguments(2))) > "%temp%\calculatePercent.vbs"
for /f "tokens=*" %%i in ('2^>nul cscript //nologo "%temp%\calculatePercent.vbs" %current% %total% %decimals%') do set "percent=%%i"
exit /b

:strLen <variable stringVar> <out variable lenVar>
set "s=A!%~1!" %\n%
set "len=0" 
for %%P in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
  if not "!s:~%%P,1!" == "" ( 
    set /a "len+=%%P" 
    set "s=!s:~%%P!" 
  ) 
)
set "%~2=!len!" 
exit /b !len!


:randomString <length> <varName> 
set len=%~1
set charpool=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 
::call :strLen charpool len_charpool
set len_charpool=63
set gen_str=
for /L %%b IN (1, 1, %len%) do (
  set /A rnd_index=!RANDOM! * %len_charpool% / 32768
  for /F %%i in ('echo %%charpool:~!rnd_index!^,1%%') do set gen_str=!gen_str!%%i
)
:: Make sure gen_str is not longer than the specified length, in the !len! variable
set /a gen_str_len=%len%
call :strLen gen_str gen_str_len
set gen_str_len=%errorlevel%
if %gen_str_len% GTR %len% set gen_str=!gen_str:~0,%len%!
set %~2=%gen_str%
exit /b

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
for /f "tokens=*" %%i in ('2^>nul cscript //nologo "%temp%\eval.vbs" %*') do set "output=%%i"

exit /b

:LoadLog <conditionP> <string>
set delay=100
if not "%~2" == "" echo.%~2
:BeginLoadLoop
  set n=0
  :SL
  set /a n+=1
  call :ied2 !delay! "%~1" [=―――――――] 
  call :ied2 !delay! "%~1" [―=――――――] 
  call :ied2 !delay! "%~1" [――=―――――] 
  call :ied2 !delay! "%~1" [―――=――――] 
  call :ied2 !delay! "%~1" [――――=―――] 
  call :ied2 !delay! "%~1" [―――――=――] 
  call :ied2 !delay! "%~1" [――――――=―] 
  call :ied2 !delay! "%~1" [―――――――=] 
  call :ied2 !delay! "%~1" [――――――=―] 
  call :ied2 !delay! "%~1" [―――――=――] 
  call :ied2 !delay! "%~1" [――――=―――] 
  call :ied2 !delay! "%~1" [―――=――――] 
  call :ied2 !delay! "%~1" [――=―――――] 
  call :ied2 !delay! "%~1" [―=――――――] 
  if !n! leq 1 goto SL
  call :ied2 !delay! "%~1" [=―――――――] 
  call :ied2 !delay! "%~1" [==――――――] 
  call :ied2 !delay! "%~1" [===―――――] 
  call :ied2 !delay! "%~1" [====――――] 
  call :ied2 !delay! "%~1" [=====―――] 
  call :ied2 !delay! "%~1" [======――] 
  call :ied2 !delay! "%~1" [=======―] 
  call :ied2 !delay! "%~1" [========] 
  call :ied2 !delay! "%~1" [―=======] 
  call :ied2 !delay! "%~1" [――======] 
  call :ied2 !delay! "%~1" [―――=====] 
  call :ied2 !delay! "%~1" [――――====] 
  call :ied2 !delay! "%~1" [―――――===] 
  call :ied2 !delay! "%~1" [――――――==] 
  call :ied2 !delay! "%~1" [―――――――=] 
  call :ied2 !delay! "%~1" [――――――==] 
  call :ied2 !delay! "%~1" [―――――===] 
  call :ied2 !delay! "%~1" [――――====] 
  call :ied2 !delay! "%~1" [―――=====] 
  call :ied2 !delay! "%~1" [――======] 
  call :ied2 !delay! "%~1" [―=======] 
  call :ied2 !delay! "%~1" [========] 
  call :ied2 !delay! "%~1" [=======―] 
  call :ied2 !delay! "%~1" [======――] 
  call :ied2 !delay! "%~1" [=====―――] 
  call :ied2 !delay! "%~1" [====――――] 
  call :ied2 !delay! "%~1" [===―――――] 
  call :ied2 !delay! "%~1" [==――――――] 
GOTO BeginLoadLoop
:EndLoadLoop
call :iecho [========]
echo.
chcp 437 > nul
exit

:ieDelay <delay> <string>
call :delay %~1
:: Remove the first argument from the list of arguments
set "args=%*"
set "args=!args:%~1 =!"
set "args=!args:%~1=!"
call :iecho %args%
exit /b


:ied2 <delay> <conditionFile> <string>
call :delay %~1
set "args=%*"
set "args=!args:%1 =!"
set "args=!args:%1=!"
set "args=!args:%2 =!"
set "args=!args:%2=!"
call :iecho %args%
:: Add a condition check here to see if the parent loop should continue
if not exist %~2 goto :EndLoadLoop
for /f "tokens=* eol=#" %%i in ('type %~2 2^> nul') do (
  if "%%i" == "0" goto :EndLoadLoop
)
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
set string=!string:•=%%!
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
exit /b %err%