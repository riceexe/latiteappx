@echo off

echo DISCLAIMER: This will replace your minecraft installation with latite client. 
echo By continuing, you are accepting that things might go wrong, and things might break. Your data shouldn't get deleted,
echo but it is always smart to make a backup.
echo Things like persona cosmetics and shaders WILL GET DELETED.
pause
set LatiteDir=%userprofile%\Latite
set LatiteApp=%LatiteDir%\App

goto :checkPrivileges
:gotPrivileges

call :IsDeveloperModeEnabled
if "%errorlevel%" == "0" ( 
    echo Developer mode is enabled. 
) else ( 
    call :EnableDeveloperMode
)


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
  :: i fucking hate powertoys i was here for like an hour trying to figure out why it was fucking locked
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
powershell -command "& {Start-BitsTransfer -DisplayName "Downloading..." -Source "https://github.com/riceexe/latiteappx/releases/download/1.19.62/1.19.62.appx" -Destination "%LatiteDir%\latite.appx"}"

:: Download and add certificate
echo Adding cert...
powershell -command "& {Start-BitsTransfer -DisplayName "Downloading..." -Source "https://github.com/riceexe/latiteappx/releases/download/1.19.62/1.19.62.cer" -Destination "%LatiteDir%\latite.cer"}"
certutil -addstore -enterprise -f -v root "%LatiteDir%\latite.cer" > nul

:: Extract appx
echo Extracting appx...
rename "%LatiteDir%\Latite.appx" Latite.zip
powershell -command "& {Expand-Archive -Path "%LatiteDir%\Latite.zip" -DestinationPath "%LatiteApp% -Force"}"
::call :UnzipFile "%LatiteDir%\Latite.zip" "%LatiteApp%"
echo Registering appx...

powershell Add-AppxPackage -Path "%LatiteApp%\AppxManifest.xml" -Register
if "%errorlevel%" == "0" (
  echo Latite has been installed!
  start "" minecraft:
) else (
  echo Failed to register extracted appx, falling back to directly registering appx.
  rename "%LatiteDir%\Latite.zip" Latite.appx
  call :AppxFallback
)
del /f /q "%LatiteDir%\Latite.zip" > nul 2>&1
del /f /q "%LatiteDir%\Latite.appx" > nul 2>&1
pause
goto :EOF



:: ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~- Utils


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
::echo Executing: "%~dps0\%~nxs0"
echo =-=-=-=-=-=-=-=-=-=-=-=-=
taskkill /f /im waitfor.exe > nul 2>&1

:: short file names are required here, if you don't use them you will get errors with spaces
powershell.exe Start-Process cmd.exe -Verb RunAs -ArgumentList '/c "%~s0"'
if not "%errorlevel%" == "0" (
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
set vbs="%temp%\_.vbs"
if exist %vbs% del /f /q %vbs%
>%vbs%  echo Set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% echo If NOT fso.FolderExists(%2) Then
>>%vbs% echo fso.CreateFolder(%2)
>>%vbs% echo End If
>>%vbs% echo set objShell = CreateObject("Shell.Application")
>>%vbs% echo set FilesInZip=objShell.NameSpace(%1).items
>>%vbs% echo objShell.NameSpace(%2).CopyHere(FilesInZip)
>>%vbs% echo Set fso = Nothing
>>%vbs% echo Set objShell = Nothing
cscript //nologo %vbs%
if exist %vbs% del /f /q %vbs%
exit /b
start /b "" cmd /c del "%~f0"&exit /b
