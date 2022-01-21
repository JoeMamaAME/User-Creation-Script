# User-Creation-Script

Script for creating a new user and logging in to it using RDP

![User-Creation-Script Screenshot](READMEimg.PNG)

## Why it's needed:

Simply using "net user \<name\> /add" or adding a new user via settings will NOT fully create the user. Logging into the created user is necessary to complete the process.

## How it works:

Initially the script asks the user for the desired username and password for the new account, and then downloads and extracts everything required for the process to %PROGRAMFILES%\RDP Wrapper.

### User Creation and RDP Setup

Once everything has been downloaded, the script creates the user using "net user \<name\> /add". The Remote Desktop Protocol (RDP) is used for logging in.

Since Windows 10 has many artificial limitations on using RDP, RDPWrap is used in its place. This allows for RDP to work on any Windows 10 version, with no hindering limitations.

Once RDPWrap is installed, a simple registry change is made to disable the privacy menu when a new user logs in. This is needed otherwise the process can't be automated.

### User Login

After the registry change is made, wFreeRDP is used to login. This program allows for automatically entering the username and password to the new account. Using 127.0.0.2 as a connection IP, it can connect to the same computer it's running on. At this point, a scheduled task for user logoff is also created.

Ideally the wFreeRDP taskbar icon should be hidden, but it seemed to be impossible to start it as Hidden (Using PowerShell's Start-Process -WindowStyle Hidden did not work). So, instead, once the script detects the wFreeRDP window is open, it hides it.

### User Logoff and Exit wFreeRDP

Once wFreeRDP is hidden, the script then waits for the user to be fully logged in. It does this by checking the Windows event logs for ID "1003" (or "1073742827" when queried by PowerShell's Get-EventLog). This event happens at the end of the user login. Once it detects the event, it runs the scheduled task mentioned before. This task runs the command "CMD /c 'shutdown -l -f'" under the currently logged in new user. At this point "TASKKILL /F /FI "ImageName eq wfreerdp.exe" is also run.

### Removal

After the user has been logged off and wFreeRDP exitted, the script reverts everything. That is, it deletes the scheduled task, removes the registry change, uninstalls RDPWrap, and removes all downloaded/extracted files, in that order.