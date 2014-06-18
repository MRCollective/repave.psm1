repave.psm1
==========

A PowerShell module that allows you to easily create a terse re-pave script for a Windows Machine making heavy use of Chocolatey.

It focusses on speed and idempotency allowing you to add to the script as you go about the business of adding software to your machine. That way when it comes time to do the next repave it's good to go rather than having to spend half a day figuring out the missing software. If something is already installed then it will immediately skip it rather than invoking `cinst` to find out meaning the script should fly through to the end if you are simply adding a new installation at the bottom.

Furthermore, if something goes wrong at any point then it will fail fast and it will store an installation log for you so you can review what it did.

Look at `robdmoore.ps1` or `MattDavies.ps1` for examples of how to use the scripts. These are the scripts that we actually use for our machines.

Feel free to fork this and add your own script. Also feel free to send pull requests or raise issues if you have ideas / questions.

Get us via Twitter at: [@robdmoore](http://twitter.com/robdmoore) / [@mdaviesnet](http://twitter.com/mdaviesnet).

Minimum example
---------------

To get started all you need is this in a `.ps1` file:

```powershell
Import-Module "$(Split-Path $MyInvocation.MyCommand.Path)\repave.psm1" -Force
Invoke-Repave {
    # Stuff to install
}
```

When you run it you must be in admin mode and after running there will be an `repave.log` file with the output and a `todo.txt` file with items for further action (unless you ran the script from PowerShell ISE, in which case there is no `repave.log`).

Functions
---------

### Invoke-Repave $script

Invokes `$script` as a code block after setting up and shutting down the repave environment before and after it respectively.

Setting up the environment involves:

1. Writing an error and exiting with non-zero exit code if the script is not executed with admin privileges
2. Invoking `Start-Script` (see below)
3. Creating a try block
    1. Creating an `Installers` directory if it doesn't already exist (used as a cache for installers that are downloaded)
    2. If the user is running in PowerShell ISE then outputting a warning that there will be no transcript
    3. If the user is not running in PowerShell ISE then starting a transcript for `repave.log` in append mode (i.e. subsequent runs will append to the log)
    4. Invoking `Install-Chocolatey` (see below)
    5. Invoking `Install-WebPI` (see below)

Shutting down the environment involves:

1. Write a warning to remind the user to clear the temp path
2. If a transcript is running then stop it
3. Catch any exceptions and:
    1. Write an error
    2. If a transcript is running then stop it
    3. Exit with non-zero exit code

### Start-Script

1. Gets the path of the `.ps1` script being executed and saves it to a global variable called `$scriptpath`; you can use this variable from your scripts
2. Changes directory to `$scriptpath` so any local file references will be local to the script no matter what the working directory was when the script was first executed
3. Sets `$ErrorActionPreference` to `stop` so any errors will cause an exception to throw and the repave script to early exit
    * There is currently a bug where problems in programs that are executed (e.g. `cinst`) don't propagate out

### Install-Chocolatey

Install Chocolatey if not already installed (and record which Chocolatey packages were installed when the script was first run so it can detect if it should invoke `cinst` when installing packages - this is a huge speed boost on subsequent script runs).

### Install-WebPI

Install web platform installer commandline. Note: Won't work unless .NET 3.5 is installed on the machine.

### Get-SourcePath

Returns the value of the global `$scriptpath` variable setup by `Start-Script` / `Invoke-Repave`.

### Test-Administrator

Returns `$true` if running with admin priviliges.

### Test-VirtualMachine

Returns `$true` if running in a Virtual Machine.

### Set-AdvancedWindowsExplorerOptions

Sets "Show Hidden Files", "Show File Extensions" and "Show System Files" in Windows Explorer.

### Install-EncryptingFilesystemCert($pfx, $rootPfx)

Securely prompts for a password and installs the given `$pfx` file to `CurrentUser\My` and the given `$rootPfx` file to `CurrentUser\TrustedPeople` using the given password for both certs.

### Install-IntelRST

Downloads Intel Rapid Storage Technology (RST) to `Installers\SetupRST.exe` unless it's already there and then runs it and outputs a warning to download trimcheck.exe to check if TRIM is enabled for the HDD.

Note: This install isn't unattended - you have to click through the setup. If you know a way of making it unattended that let us know.

### Install-Git

Install of:

* msysgit
* TortoiseGit
* poshgit
* `C:\Program Files (x86)\Git\bin` in `%PATH%`
* Copying the `.ssh` folder (if present relative to the script) to `~` if not already there
    * If it is present then TortoiseGit is configured to use `ssh.exe` rather than `PLink.exe`
* Copying the `.gitconfig` file (if present relative to the script) to `~` if not already there

### Install-IIS

Installs IIS using Windows Features.

### Install-WebDeploy35

Installs Web Deploy 3.5 using WebPI.

### Install-VisualStudio2013($product, $features, $onInstall)

Installs Visual Studio 2013 using Chocolatey.

`$product` can be one of "ExpressWeb", "Professional" (default), "Premium" or "Ultimate".

`$features` is a space delimited string of features to install, default is "WebTools SQL Win8SDK Win81SDK WindowsPhone80 WindowsPhone81 OfficeDeveloperTools Blend LightSwitch".

`$onInstall` is an optional code block to execute if Visual Studio is being installed.

### Install-VisualStudio2013Iso($iso, $onInstall)

Installs Visual Studio 2013 using the given `.iso` file.

`$onInstall` is an optional code block to execute if Visual Studio is being installed.

### Restore-ReSharperExtensions($pathToPackagesConfig)

Copies the given `packages.config` file to `%APPDATA%\JetBrains\ReSharper\vAny` if not already there so that next time you bring up the ReSharper Extension Manager you can click Restore to restore the packages. It will output a warning to remind you to do that.

### Install-AzureSDK2.3

Installs Windows Azure SDK 2.3, Windows Azure 2.3 Tools for Visual Studio 2013 and the Windows Azure PowerShell commandlets all using WebPI.

Currently, this doesn't work because the latest version of webpicmd is needed, but it fails due to path issues. If you manually install webpicmd as the latest version and fix the path issues then you can run this successfully.

### Install-Office2013Iso($iso, $msp)

Installs Office 2013 using the given `.iso` and `.msp` files. Generate a `.msp` by mounting the iso and invoking `setup.exe /admin`.

### Install-OutlookSignatures($signaturesPath)

Copies the given `Signatures` folder to "%APPDATA%\Microsoft\Signatures" if not already there.

### Add-ToPath($path)

Reloads the `%PATH%` and appends the given path to the end of it if it's not already in there.

### Set-TortoiseGitToUseSshKeys()

Sets the appropriate registry entry for TortoiseGit to use `C:\Program Files (x86)\Git\bin\ssh.exe` as the SSH client.

### Set-TaskBarPin($path, $exe)

Pins the given `$exe` inside of the given `$path` to the taskbar.

### Set-TaskBarPinChrome

Pins Chrome to the taskbar.

### Set-TaskBarPinOutlook2013

Pins Outlook 2013 to the taskbar.

### Set-TaskBarPinVisualStudio2013

Pins Visual Studio 2013 to the taskbar.

### Set-TaskBarPinLinqpad4

Pins Linqpad4 to the taskbar.

### Set-TaskBarPinLync2013

Pins Lync 2013 to the taskbar.

### Set-TaskBarPinOneNote2013

Pins OneNote 2013 to the taskbar.

### Set-TaskBarPinRDP

Pins MSTSC (RDP client) to the taskbar.

### Set-TaskBarPinSSMS2014

Pins SQL Server 2014 Management Studio to the taskbar.

### Set-TaskBarPinSQLProfiler2014

Pins SQL Server 2014 Profiler to the taskbar.

### Set-TaskBarPinPaintDotNet

Pins Paint.NET to the taskbar.

### Install-VS2013Extension($vsixUrl)

Downloads and installs the given VSIX to Visual Studio. Note: this is not idempotent since there is no way to tell if an extension is installed (if you know how let us know!). Recommendation is that this is done using the `$onInstall` parameter to the commands to install Visual Studio (see above).

### `Install-ChocolateyPackage $PackageName [-InstallArgs <InstallArgs>] [-RunIfInstalled { <code> }]`

Installs the given Chocolatey package if it's not already installed. Optionally pass `-InstallArgs` to add extra Chocolatey installation arguments or `-RunIfInstalled` to run some code if the given package is being installed.

### Install-ITunesMusicLibrary($pathToMusicLibrary)

Copies the given `iTunes` folder to "~\Music" if not already there.

### Install-AzureManagementStudio

Downloads Azure Management Studio installer to `Installers\AzureManagementStudio.exe` unless it's already there and then runs it.

Note: the download doesn't seem to currently work and the installer requires you to click on it - it's not quiet. If anyone knows how to fix this let us know.

### Install-HyperV

Installs Hyper-V from Windows Features.

### Install-SQLServerExpress2014AndManagementStudio

If you have downloaded [SQLEXPRWT_x64_ENU.exe](http://care.dlservice.microsoft.com/dl/download/E/A/E/EAE6F7FC-767A-4038-A954-49B8B05D04EB/SQLEXPRWT_x64_ENU.exe) and extracted it to `Installers\SQLEXPRWT_x64_ENU\` then it will install SQL Server Express 2014 and SQL Server Management Studio from that location.

### Add-Todo $message

Writes a warning of $message and appends that message to `todo.txt`.

### Add-ExplorerFavourite $name, $folder

Adds a favourite link in Windows Explorer with the given name pointing to the given folder location.
