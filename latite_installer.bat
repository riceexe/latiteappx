@:: Latite Appx Installer
@:: by rice#2532 and VastraKai#0001
@if not "%debug%" == "true" @echo off 
:: The version of Latite to install.
set LatiteVersion=1.20.1
:: The directory to use for installation.
set LatiteDir=%userprofile%\Latite
:: The directory to install the appx to.
set LatiteApp=%LatiteDir%\App
set LatiteAppxUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.appx
set LatiteCertUrl=https://github.com/riceexe/latiteappx/releases/download/%LatiteVersion%/%LatiteVersion%.cer
setlocal EnableDelayedExpansion EnableExtensions
set "originalArgs=%*"
set "currentFile=%~0"

:: so the formatting doesn't go all weird when the console outputs a unicode character
> %temp%\tmp.reg echo Windows Registry Editor Version 5.00
>> %temp%\tmp.reg echo.
>> %temp%\tmp.reg echo [HKEY_CURRENT_USER\Console\%%SystemRoot%%_System32_cmd.exe]
>> %temp%\tmp.reg echo "ScreenBufferSize"=dword:23290096
>> %temp%\tmp.reg echo "WindowSize"=dword:00320096
>> %temp%\tmp.reg echo "FontFamily"=dword:00000036
>> %temp%\tmp.reg echo "FontWeight"=dword:00000190
>> %temp%\tmp.reg echo "FaceName"="Lucida Console"
>> %temp%\tmp.reg echo "CursorType"=dword:00000000
>> %temp%\tmp.reg echo "InterceptCopyPaste"=dword:00000000
>> %temp%\tmp.reg echo "FontSize"=dword:000f0009
2>nul reg query HKCU\Console /v VirtualTerminalLevel | findstr /i /c:"0x1" >nul 2>&1
if not "%errorlevel%" == "0" (
  reg add HKEY_CURRENT_USER\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f > nul 2>&1
  set "Restart=1"
)
reg query HKEY_CURRENT_USER\Console\%%SystemRoot%%_System32_cmd.exe > nul 2>&1
if not "%errorlevel%" == "0" (
  reg import %temp%\tmp.reg > nul 2>&1
  del /f /q "%temp%\tmp.reg" > nul 2>&1
  set "Restart=1"
)
if "%Restart%" == "1" (
  set Restart=
  goto :ElevationFallback
)
del /f /q "%temp%\tmp.reg" > nul 2>&1
chcp 65001 > nul

if not defined ASCII_13 for /f %%a in ('2^>nul copy /Z "%~dpf0" nul') do set "ASCII_13=%%a"
if not defined CR for /F %%C in ('2^>nul copy /Z "%~f0" nul') do set "CR=%%C"
if not defined BS for /F %%C in ('2^>nul echo prompt $H ^| 2^>nul cmd') do set "BS=%%C"
if not defined \E for /F %%e in ('echo prompt $E^|cmd') do set "\E=%%e"

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
title Latite %LatiteVersion% Appx Installer
if /i not "%~1" == "--uninstall" (
  echo.
  echo DISCLAIMER: This will replace your minecraft installation with latite client. 
  echo By continuing, you are accepting that things might go wrong, and things might break. Your data shouldn't get deleted,
  echo but it is always smart to make a backup.
  echo Things like persona cosmetics and shaders WILL GET DELETED.
  call :pause
  echo.
)



:: Remove current Minecraft bedrock installation
taskkill /f /im Minecraft.Windows.exe >nul 2>&1

call :RunCmdWithLoading "Removing current Minecraft installation..." 1 call :RemoveOldMcStuff

if /i "%~1" == "--uninstall" (
  echo.
  echo Latite has been uninstalled.
  call :PauseIf
  goto :EOF
)

> nul 2>&1 md "%LatiteDir%"
> nul 2>&1 md "%LatiteApp%"


:: Download appx
echo Downloading Latite %LatiteVersion%...
call :DownloadFile "%LatiteAppxUrl%" "%LatiteDir%\latite.appx"

:: Download and add certificate
echo Adding certificate...
call :DownloadFile "%LatiteCertUrl%" "%LatiteDir%\latite.cer"
certutil -addstore -enterprise -f -v root "%LatiteDir%\latite.cer" > nul

set DepsAlreadyInstalled=1
call :iecho Checking dependencies ^(1/3^)...
powershell Get-AppxPackage Microsoft.Services.Store.Engagement* | findstr /I /C:"x64" > nul 2>&1
if not "%errorlevel%" == "0" (
  set DepsAlreadyInstalled=0
  call :iEcho Downloading Microsoft.Services.Store.Engagement.x64.appx...
  echo.
  call :DownloadFile "https://vastrakai.wtf/downloads/Microsoft.Services.Store.Engagement.x64.appx" "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx"
  call :RunCmdWithLoading "Installing Microsoft.Services.Store.Engagement.x64..." 0 powershell Add-AppPackage "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" -ForceApplicationShutdown
)
call :iecho Checking dependencies ^(2/3^)...
powershell Get-AppxPackage Microsoft.VCLibs* | findstr /I /C:"x64" > nul 2>&1
if not "%errorlevel%" == "0" (
  set DepsAlreadyInstalled=0
  call :iEcho Downloading Microsoft.VCLibs.x64.appx...
  echo.
  call :DownloadFile "https://vastrakai.wtf/downloads/Microsoft.VCLibs.x64.appx" "%LatiteDir%\Microsoft.VCLibs.x64.appx"
  call :RunCmdWithLoading "Installing Microsoft.VCLibs.x64..." 0 powershell Add-AppPackage "%LatiteDir%\Microsoft.VCLibs.x64.appx" -ForceApplicationShutdown
)
call :iecho Checking dependencies ^(3/3^)...
call :IsRedistInstalled
if not "%errorlevel%" == "0" (
  set DepsAlreadyInstalled=0
  call :iEcho Downloading Visual C++ Redistributable x64...
  echo.
  call :DownloadFile "https://aka.ms/vs/17/release/vc_redist.x64.exe" "%LatiteDir%\vc_redist.x64.exe"
  call :RunCmdWithLoading "Installing Visual C++ Redistributable x64..." 0 "%LatiteDir%\vc_redist.x64.exe" /install /quiet /norestart
)
:trydelete
del /f /q "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\Microsoft.VCLibs.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\vc_redist.x64.exe" > nul 2>&1
if exist "%LatiteDir%\vc_redist.x64.exe" goto :trydelete
if "%DepsAlreadyInstalled%" == "1" (
  call :iecho 3/3 dependencies installed.
  echo.
) else (
  set errs=0
  powershell Get-AppxPackage Microsoft.Services.Store.Engagement* | findstr /I /C:"x64" > nul 2>&1
  set /a errs=!errs! + !errorlevel!
  powershell Get-AppxPackage Microsoft.VCLibs* | findstr /I /C:"x64" > nul 2>&1
  set /a errs=!errs! + !errorlevel!
  call :IsRedistInstalled
  set /a errs=!errs! + !errorlevel!
  if "!errs!" == "0" echo 3/3 dependencies installed. You may need to restart your computer.
  if "!errs!" == "1" echo 1 dependency failed to install^^!
  if not "!errs!" == "0" if not "!errs!" == "1" echo !errs! dependencies failed to install^^!
  echo.
)
call :RunCmdWithLoading "Checking modules..." 1 call :Install7ZModule
call :RunCmdWithLoading "Extracting latite.appx to %LatiteApp%..." 0 call :UnzipFile "%LatiteDir%\latite.appx" "%LatiteApp%"
:: echo Registering appx...
:: powershell Add-AppxPackage -Path "%LatiteApp%\AppxManifest.xml" -Register
call :RunCmdWithLoading "Registering appx..." 0 powershell Add-AppxPackage -Path "%LatiteApp%\AppxManifest.xml" -Register
if "%errorlevel%" == "0" (
  call :CleanUp
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
  call :CleanUp
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
  call :CleanUp
  del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
  del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
  start "" minecraft:
  echo Latite has been installed^^!
  pause
  goto :EOF
)
echo Install failed^^!
call :CleanUp
pause
goto :EOF

:: ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~- Utils

:CleanUp
call :RunCmdWithLoading "Cleaning up..." 1 call :CleanUp2
exit /b

:CleanUp2
del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
del /f /q "%LatiteDir%\Microsoft.Services.Store.Engagement.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\Microsoft.VCLibs.x64.appx" > nul 2>&1
del /f /q "%LatiteDir%\vc_redist.x64.exe" > nul 2>&1
call :RmAll %temp%
exit /b

:RmAll <string dir>
rmdir /s /q "%*" 2>nul
md "%*" > nul 2>&1
exit /b

:RunCmdWithLoading <message> <removeWhenDone> <command> 
set num=0
set "loadingLog=%temp%\"
call :randomString 40 rndFile
set "loadingLog=%loadingLog%LTI_%rndFile%.tmp"
> "%loadingLog%" echo.1
set command=%*
set command=!command:%1 =!
set command=!command:%1=!
if not "%2" == "" set command=!command:%2 =!
if not "%2" == "" set command=!command:%2=!
start /b "" cmd /c %currentFile% --internal LoadLog "%loadingLog%" "%~1" "%~2"
%command%
set err=%errorlevel%
> "%loadingLog%" echo.0
timeout -t 1 -nobreak > nul 2>&1
del /f /q "%loadingLog%" > nul 2>&1
exit /b %err%

:GetContentLength <url>
for /f "tokens=*" %%i in ('powershell -command "& { Add-Type -AssemblyName System.Net.Http; (New-Object System.Net.Http.HttpClient).SendAsync([System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod] 'Head', '%~1')).Result.Content.Headers.ContentLength }"') do set size=%%i
exit /b

:RemoveOldMcStuff
call :IsMinecraftInstalled
if not "%errorlevel%" == "0" goto :Rm2
:: The launcher sometimes locks the AppxManifest for some reason, so i have to kill it
:: Keep in mind, this will not affect the functionality of PowerToys
taskkill /f /im PowerToys.PowerLauncher.exe > nul 2>&1
powershell Get-AppxPackage Microsoft.MinecraftUWP* ^| Remove-AppxPackage -PreserveRoamableApplicationData
2>nul call :IsMinecraftInstalled
if "%errorlevel%" == "0" goto :RemoveOldMcStuff
if exist "%LatiteApp%" rmdir /q /s "%LatiteApp%" > nul 2>&1
if exist "%LatiteDir%" rmdir /q /s "%LatiteDir%" > nul 2>&1
if exist "%LatiteApp%" rmdir /q /s "%LatiteApp%" > nul 2>&1
if exist "%LatiteDir%" rmdir /q /s "%LatiteDir%" > nul 2>&1
exit /b

:Rm2
if exist "%LatiteApp%" rmdir /q /s "%LatiteApp%" > nul 2>&1
if exist "%LatiteDir%" rmdir /q /s "%LatiteDir%" > nul 2>&1
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
set oldPercent=%percent%
set "progressBarString="
set "barsString="
set "bars2==================================================="
set "spacesString=                                                  "
set "progressBarLength=50"
set "barChar=="
call :evalVbs Round^^(%percent%^^)
set "roundedPercent=%output%"
set /a percentPerBar=100 / %progressBarLength%
set /a bars=%roundedPercent% / %percentPerBar%
set /a targetBars=%roundedPercent% / %percentPerBar%
set "barsString=!bars2:~0,%bars%!"
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
set "progressBarString=[%progressBarString%] (%downSpeed%/s)"%=why is this necessary=%
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
set len_charpool=63
set gen_str=
for /L %%b IN (1, 1, %len%) do (
  set /A rnd_index=!RANDOM! * %len_charpool% / 32768
  for /F %%i in ('echo %%charpool:~!rnd_index!^,1%%') do set gen_str=!gen_str!%%i
)
set /a gen_str_len=%len%
call :strLen gen_str gen_str_len
set gen_str_len=%errorlevel%
if %gen_str_len% GTR %len% set gen_str=!gen_str:~0,%len%!
set %~2=%gen_str%
exit /b

:PauseIf
echo %cmdcmdline% | ^
findstr /i /c:"C:\WINDOWS\system32\cmd.exe /c \"\"" > nul 2>&1 ^
&& pause
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

:LoadLog <conditionP> <string> <removeWhenDone>
echo off
set removeWhenDone=%~3
set removeWhenDone=!removeWhenDone: =!
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

if "!removeWhenDone!" == "1" (
  call :iecho %\E%[1A
  call :iecho 
) else (
  call :iecho [========] 
  echo.
)
exit

:pause [string]
set "args=%~1"
if "%args%" == "" set "args=Press any key to continue . . ."
call :iecho %args%
pause > nul
call :iecho 
exit /b

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
powershell Get-AppxPackage Microsoft.MinecraftUWP* 2>nul | findstr /i /c:"microsoft.minecraftuwp" > nul 2>&1
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

:ElevationFallback
net file 1>NUL 2>NUL
if not "%errorlevel%" == "0" (
  echo.
  echo =-=-=-=-=-=-=-=-=-=-=-=-=
  echo Waiting for elevation...
  echo =-=-=-=-=-=-=-=-=-=-=-=-=
)
set params=%*
if not "%params%" == "" set "params= %params%"
> %temp%\LTIConSetup.vbs echo Set objShell = CreateObject^("Shell.Application"^)
>> %temp%\LTIConSetup.vbs echo If WScript.Arguments.length =0 then
>> %temp%\LTIConSetup.vbs echo   WScript.Echo(objShell.ShellExecute("wscript.exe", Chr(34) ^& WScript.ScriptFullName ^& Chr(34) ^& " uac", "", "runas", 1))
>> %temp%\LTIConSetup.vbs echo Else
>> %temp%\LTIConSetup.vbs echo   objShell.ShellExecute "%WinDir%\System32\cmd.exe", "/c %~0%params%", "%cd%", "runas", 1
>> %temp%\LTIConSetup.vbs echo End If
>> %temp%\LTIConSetup.vbs echo WScript.Quit()
cscript //Nologo %temp%\LTIConSetup.vbs > %temp%\LTIElevSetup.log
if not "%errorlevel%" == "0" (
  type %temp%\LTIElevSetup.log
  echo Error: Elevation failed with code %errorlevel% ^(using VBScript^). Please report this^^!
  echo Press any key to exit...
  timeout -t 2 -nobreak > nul
  del /f /q %temp%\LTIConSetup.vbs
  del /f /q %temp%\LTIElevSetup.log
  pause > nul
  exit /b 1
)
timeout -t 1 -nobreak > nul
del /f /q %temp%\LTIConSetup.vbs
del /f /q %temp%\LTIElevSetup.log
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

:: short file names are required here, if you don't use them you will get errors with spaces
powershell.exe Start-Process cmd.exe -Verb RunAs -ArgumentList '/c "%~s0" %originalArgs%' > %temp%\LTIElevSetup.log 2>&1
if not "%errorlevel%" == "0" (
    echo.
    echo =-=-=-=-=-=-=-=-=-=-=-=-=
    echo Waiting for elevation...
    echo =-=-=-=-=-=-=-=-=-=-=-=-=
    type "%temp%\LTIElevSetup.log"
    :: Todo: Add backup elevation using vbscript
    echo Error: Elevation failed with code %errorlevel% ^(using PowerShell^). Please report this^^!
    echo Attempting elevation using VBScript...
    del /f /q "%temp%\LTIElevSetup.log" > nul 2>&1
    timeout -t 2 > nul 2>&1
    goto :ElevationFallback
) else ( exit )
exit /b

:iecho <string>
setlocal EnableDelayedExpansion
set "STRING=%*"
set "SPACCCES=                                                                             "
::set /P ="%BS%!CR!%SPACES%!CR!" < nul
if not "%string%" == "" set string=!string:•=%%!
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
