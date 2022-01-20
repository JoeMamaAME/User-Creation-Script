@ECHO OFF
NET SESSION > NUL 2>&1
IF %ERRORLEVEL% GTR 0 POWERSHELL "Start-Process '%~0' -Verb RunAs" & EXIT /B 0 > NUL 2>&1
MODE 141, 30

:MENU

ECHO _____________________________________________________________________________________________________________________________________________
ECHO.
ECHO         ^| User Creation Script ^|
ECHO.
ECHO       [1] Add new user
ECHO       [X] Exit
ECHO.
ECHO _____________________________________________________________________________________________________________________________________________
ECHO.
CHOICE /C 1X9 /N /M "Choose a menu option: "
IF %ERRORLEVEL%==1 GOTO UserInput
IF %ERRORLEVEL%==2 EXIT /B 0
IF %ERRORLEVEL%==3 ECHO. & GOTO REMOVE

:UserInput

CLS & ECHO _____________________________________________________________________________________________________________________________________________
ECHO. & ECHO         ^| User Creation Script ^| & ECHO. & ECHO. & ECHO.
SET /P "newUsername=Enter new Username: " & ECHO.
SET /P "newPassword=Enter new Password: " & ECHO.
SET "no2=rem"
REM wFreeRDP won't work with a blank password
	IF "%newPassword%"=="" SET "newPassword=123" & SET "no2="
	ECHO "%newPassword%"| FIND " " > NUL 2>&1
		IF %ERRORLEVEL% LSS 1 SET "ERRORCODE=Password cannot contain spaces!" & GOTO REMOVE

CHOICE /C YN /N /M "Make new user an Administrator? (Y/N): "
	IF %ERRORLEVEL%==2 SET "no1=rem"

:RDPWrap

REM THIS DIRECTORY IS IMPORTANT, autoupdate.bat requires it according to: https://github.com/asmtron/rdpwrap/blob/master/binary-download.md
MKDIR "%PROGRAMFILES%\RDP Wrapper"

ECHO. & ECHO Downloading and installing RDPWrap & ECHO.
CURL -L --progress-bar "https://github.com/stascorp/rdpwrap/releases/download/v1.6.2/RDPWrap-v1.6.2.zip" --output "%PROGRAMFILES%\RDP Wrapper\RDPWrap.zip">NUL & ECHO.
	FOR %%A IN ("%PROGRAMFILES%\RDP Wrapper\RDPWrap.zip") DO SET "ZipSize=%%~zA"
		REM Detects size of ZIP file, this essentially allows for a simple error detection.
		IF %ZipSize% LSS 20000 (
			RMDIR /S /Q "%PROGRAMFILES%\RDP Wrapper"
			SET "ERRORCODE=DL1" & GOTO REMOVE )

REM THIS IS NEEDED, RDPWrap by itself is outdated, autoupdate is maintained by another user and it allows
REM for newer versions of Windows
CURL -L --progress-bar "https://github.com/asmtron/rdpwrap/raw/master/autoupdate.zip" --output "%PROGRAMFILES%\RDP Wrapper\RDPWrapUpdate.zip">NUL & ECHO.
	FOR %%A IN ("%PROGRAMFILES%\RDP Wrapper\RDPWrapUpdate.zip") DO SET "ZipSize=%%~zA"
		IF %ZipSize% LSS 4000 (
			RMDIR /S /Q "%PROGRAMFILES%\RDP Wrapper"
			SET "ERRORCODE=DL2" & GOTO REMOVE )
REM Extract everything to %PROGRAMFILES%\RDP Wrapper
POWERSHELL -command "Expand-Archive -Path '%PROGRAMFILES%\RDP Wrapper\RDPWrap.zip' -DestinationPath '%PROGRAMFILES%\RDP Wrapper';Expand-Archive -Path '%PROGRAMFILES%\RDP Wrapper\RDPWrapUpdate.zip' -DestinationPath '%PROGRAMFILES%\RDP Wrapper'"

ECHO Running RDPWrap installer script... & ECHO.
CALL "%PROGRAMFILES%\RDP Wrapper\autoupdate.bat" > NUL 2>&1

:UserCreation

ECHO Adding user... & ECHO.
NET user "%newUsername%" "%newPassword%" /add
	IF %ERRORLEVEL% GTR 0 SET "ERRORCODE=Incorrect username or password" & GOTO REMOVE
REM This is needed for the RDP connection, "Remote Desktop Users" does NOT work on Windows 10 Home
NET localgroup Administrators "%newUsername%" /add

:UserLogin

ECHO Downloading wFreeRDP... & ECHO.
CURL -L --progress-bar "https://ci.freerdp.com/job/freerdp-nightly-windows/arch=win64,label=vs2013/lastStableBuild/artifact/build/Release/wfreerdp.exe" --output "%PROGRAMFILES%\RDP Wrapper\wfreerdp.exe" & ECHO.
	FOR %%A IN ("%PROGRAMFILES%\RDP Wrapper\wfreerdp.exe") DO SET "EXESize=%%~zA"
		IF %EXESize% LSS 3000 (
		SET "ERRORCODE=DL3"
		GOTO REMOVE )

ECHO Disabling privacy menu via registry... & ECHO.
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f & ECHO.

ECHO Creating logoff scheduled task... & ECHO.
SCHTASKS /CREATE /tn UserCreateLogoff /tr "CMD /c 'SHUTDOWN -l -f'" /sc ONSTART /ru "%newUsername%" /it /f /rl HIGHEST & ECHO.

REM Grabs current time, needed for event log time scope
FOR /F "tokens=2" %%A IN ('DATE /T') DO SET "dateAfter=%%A"
SET "timeAfter=%TIME:~0,-3%"

ECHO Running wFreeRDP... & ECHO.
START /min "" "%PROGRAMFILES%\RDP Wrapper\wfreerdp.exe" "/h:1" "/w:1" "/cert-ignore" "/v:127.0.0.2" "/u:%newUsername%" "/p:%newPassword%"
SET "count=1"
:hideLoop
	SET /A "count=%count%+1"
		IF %count% GTR 60 SET "ERRORCODE=WL4" & GOTO REMOVE
	TIMEOUT /T 1 /NOBREAK > NUL
	IF NOT EXIST "%SYSTEMDRIVE%\Users\%newUsername%" GOTO HideLoop
REM At this point wFreeRDP's window is open, and can be hidden

ECHO Hiding wFreeRDP Window... & ECHO.
REM This was converted from the script posted by bobmccoy here: https://community.spiceworks.com/topic/664020-maximize-an-open-window-with-powershell-win7
REM Use a Base64 to Text converter to see the changes.
POWERSHELL -encodedCommand "ZgB1AG4AYwB0AGkAbwBuACAAUwBlAHQALQBXAGkAbgBkAG8AdwBTAHQAeQBsAGUAIAB7AA0ACgBwAGEAcgBhAG0AKAANAAoAIAAgACAAIABbAFAAYQByAGEAbQBlAHQAZQByACgAKQBdAA0ACgAgACAAIAAgAFsAVgBhAGwAaQBkAGEAdABlAFMAZQB0ACgAJwBGAE8AUgBDAEUATQBJAE4ASQBNAEkAWgBFACcALAAgACcASABJAEQARQAnACwAIAAnAE0AQQBYAEkATQBJAFoARQAnACwAIAAnAE0ASQBOAEkATQBJAFoARQAnACwAIAAnAFIARQBTAFQATwBSAEUAJwAsACAADQAKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAnAFMASABPAFcAJwAsACAAJwBTAEgATwBXAEQARQBGAEEAVQBMAFQAJwAsACAAJwBTAEgATwBXAE0AQQBYAEkATQBJAFoARQBEACcALAAgACcAUwBIAE8AVwBNAEkATgBJAE0ASQBaAEUARAAnACwAIAANAAoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACcAUwBIAE8AVwBNAEkATgBOAE8AQQBDAFQASQBWAEUAJwAsACAAJwBTAEgATwBXAE4AQQAnACwAIAAnAFMASABPAFcATgBPAEEAQwBUAEkAVgBBAFQARQAnACwAIAAnAFMASABPAFcATgBPAFIATQBBAEwAJwApAF0ADQAKACAAIAAgACAAJABTAHQAeQBsAGUAIAA9ACAAJwBTAEgATwBXACcALAANAAoAIAAgACAAIABbAFAAYQByAGEAbQBlAHQAZQByACgAKQBdAA0ACgAgACAAIAAgACQATQBhAGkAbgBXAGkAbgBkAG8AdwBIAGEAbgBkAGwAZQAgAD0AIAAoAEcAZQB0AC0AUAByAG8AYwBlAHMAcwAgAC0ASQBkACAAJABwAGkAZAApAC4ATQBhAGkAbgBXAGkAbgBkAG8AdwBIAGEAbgBkAGwAZQANAAoAKQANAAoAIAAgACAAIAAkAFcAaQBuAGQAbwB3AFMAdABhAHQAZQBzACAAPQAgAEAAewANAAoAIAAgACAAIAAgACAAIAAgAEYATwBSAEMARQBNAEkATgBJAE0ASQBaAEUAIAAgACAAPQAgADEAMQA7ACAASABJAEQARQAgACAAIAAgACAAIAAgACAAIAAgACAAIAA9ACAAMAANAAoAIAAgACAAIAAgACAAIAAgAE0AQQBYAEkATQBJAFoARQAgACAAIAAgACAAIAAgACAAPQAgADMAOwAgACAATQBJAE4ASQBNAEkAWgBFACAAIAAgACAAIAAgACAAIAA9ACAANgANAAoAIAAgACAAIAAgACAAIAAgAFIARQBTAFQATwBSAEUAIAAgACAAIAAgACAAIAAgACAAPQAgADkAOwAgACAAUwBIAE8AVwAgACAAIAAgACAAIAAgACAAIAAgACAAIAA9ACAANQANAAoAIAAgACAAIAAgACAAIAAgAFMASABPAFcARABFAEYAQQBVAEwAVAAgACAAIAAgACAAPQAgADEAMAA7ACAAUwBIAE8AVwBNAEEAWABJAE0ASQBaAEUARAAgACAAIAA9ACAAMwANAAoAIAAgACAAIAAgACAAIAAgAFMASABPAFcATQBJAE4ASQBNAEkAWgBFAEQAIAAgACAAPQAgADIAOwAgACAAUwBIAE8AVwBNAEkATgBOAE8AQQBDAFQASQBWAEUAIAA9ACAANwANAAoAIAAgACAAIAAgACAAIAAgAFMASABPAFcATgBBACAAIAAgACAAIAAgACAAIAAgACAAPQAgADgAOwAgACAAUwBIAE8AVwBOAE8AQQBDAFQASQBWAEEAVABFACAAIAA9ACAANAANAAoAIAAgACAAIAAgACAAIAAgAFMASABPAFcATgBPAFIATQBBAEwAIAAgACAAIAAgACAAPQAgADEADQAKACAAIAAgACAAfQANAAoAIAAgACAAIABXAHIAaQB0AGUALQBWAGUAcgBiAG8AcwBlACAAKAAiAFMAZQB0ACAAVwBpAG4AZABvAHcAIABTAHQAeQBsAGUAIAB7ADEAfQAgAG8AbgAgAGgAYQBuAGQAbABlACAAewAwAH0AIgAgAC0AZgAgACQATQBhAGkAbgBXAGkAbgBkAG8AdwBIAGEAbgBkAGwAZQAsACAAJAAoACQAVwBpAG4AZABvAHcAUwB0AGEAdABlAHMAWwAkAHMAdAB5AGwAZQBdACkAKQANAAoADQAKACAAIAAgACAAJABXAGkAbgAzADIAUwBoAG8AdwBXAGkAbgBkAG8AdwBBAHMAeQBuAGMAIAA9ACAAQQBkAGQALQBUAHkAcABlACAAEyBtAGUAbQBiAGUAcgBEAGUAZgBpAG4AaQB0AGkAbwBuACAAQAAdICAADQAKACAAIAAgACAAWwBEAGwAbABJAG0AcABvAHIAdAAoACIAdQBzAGUAcgAzADIALgBkAGwAbAAiACkAXQAgAA0ACgAgACAAIAAgAHAAdQBiAGwAaQBjACAAcwB0AGEAdABpAGMAIABlAHgAdABlAHIAbgAgAGIAbwBvAGwAIABTAGgAbwB3AFcAaQBuAGQAbwB3AEEAcwB5AG4AYwAoAEkAbgB0AFAAdAByACAAaABXAG4AZAAsACAAaQBuAHQAIABuAEMAbQBkAFMAaABvAHcAKQA7AA0ACgAcIEAAIAAtAG4AYQBtAGUAIAAcIFcAaQBuADMAMgBTAGgAbwB3AFcAaQBuAGQAbwB3AEEAcwB5AG4AYwAdICAALQBuAGEAbQBlAHMAcABhAGMAZQAgAFcAaQBuADMAMgBGAHUAbgBjAHQAaQBvAG4AcwAgABMgcABhAHMAcwBUAGgAcgB1AA0ACgANAAoAIAAgACAAIAAkAFcAaQBuADMAMgBTAGgAbwB3AFcAaQBuAGQAbwB3AEEAcwB5AG4AYwA6ADoAUwBoAG8AdwBXAGkAbgBkAG8AdwBBAHMAeQBuAGMAKAAkAE0AYQBpAG4AVwBpAG4AZABvAHcASABhAG4AZABsAGUALAAgACQAVwBpAG4AZABvAHcAUwB0AGEAdABlAHMAWwAkAFMAdAB5AGwAZQBdACkAIAB8ACAATwB1AHQALQBOAHUAbABsAA0ACgB9AA0ACgANAAoAKABHAGUAdAAtAFAAcgBvAGMAZQBzAHMAIAAtAE4AYQBtAGUAIAB3AGYAcgBlAGUAcgBkAHAAKQAuAE0AYQBpAG4AVwBpAG4AZABvAHcASABhAG4AZABsAGUAIAB8ACAAZgBvAHIAZQBhAGMAaAAgAHsAIABTAGUAdAAtAFcAaQBuAGQAbwB3AFMAdAB5AGwAZQAgAEgASQBEAEUAIAAkAF8AIAB9AA=="

ECHO Waiting for wFreeRDP to finish, and killing it & ECHO.
SET "count=1"
:TimeLoop
	SET /A "count=%count%+1"
		IF %count% GTR 90 SET "ERRORCODE=TL5" & GOTO REMOVE
	REM When this event happens, it's at the last second of login, wFreeRDP can be killed at or even a bit before this point
	REM 1073742827 is Event ID 1003 in the GUI Event Viewer
	POWERSHELL -command "$timeAfter = Get-Date -Date '%dateAfter% %timeAfter%'; Get-EventLog -LogName Application -After $timeAfter" | FINDSTR "1073742827" > NUL
		IF %ERRORLEVEL% GTR 0 TIMEOUT /T 1 /NOBREAK>NUL & GOTO TimeLoop

ECHO Running logoff task and exiting wFreeRDP... & ECHO.
TIMEOUT /T 1 /NOBREAK > NUL
REM Runs logoff task for the new user, this is the only way I found that works for Windows 10 Home. RUNAS will not work
SCHTASKS /RUN /tn UserCreateLogoff & ECHO.
TASKKILL /F /FI "ImageName eq wfreerdp.exe" & ECHO.

ECHO Uninstalling RDPWrap and deleting everything...
SCHTASKS /DELETE /tn UserCreateLogoff /f > NUL
REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /f > NUL
CALL "%PROGRAMFILES%\RDP Wrapper\uninstall.bat" < NUL > NUL
RMDIR /S /Q "%PROGRAMFILES%\RDP Wrapper" > NUL

REM See lines 28-35
%no1% NET localgroup Administrators "%newUsername%" /delete > NUL
%no2% NET user "%newUsername%" "" > NUL

ECHO. & ECHO. & ECHO.
ECHO            Complete!
ECHO _____________________________________________________________________________________________________________________________________________
ECHO. & <NUL SET /P "Exit=Press any key to Exit..." & PAUSE>NUL & EXIT /B 0

:REMOVE

ECHO Uninstalling RDPWrap and deleting everything...
SCHTASKS /DELETE /tn UserCreateLogoff /f > NUL 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /f > NUL 2>&1
TASKKILL /F /FI "ImageName eq wfreerdp.exe" > NUL 2>&1
CALL "%PROGRAMFILES%\RDP Wrapper\uninstall.bat" < NUL > NUL 2>&1
NET user "%newUsername%" /delete > NUL 2>&1
RMDIR /S /Q "%PROGRAMFILES%\RDP Wrapper" > NUL 2>&1
ECHO. & ECHO. & ECHO.
ECHO            Failed! ERROR: %ERRORCODE%
ECHO _____________________________________________________________________________________________________________________________________________
ECHO. & <NUL SET /P "Exit=Press any key to Exit..." & PAUSE>NUL & EXIT /B 0