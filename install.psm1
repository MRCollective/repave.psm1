function Invoke-Repave($script) {
    if (-not (Test-Administrator)) {
        Write-Error "Re-open in admin mode`r`n"
        exit 1
    }
    Start-Script
    try
    {
        mkdir Installers -ErrorAction SilentlyContinue | Out-Null
        $inTranscript = $Host.Name -ne "Windows PowerShell ISE Host"
        if ($inTranscript) {
            Start-Transcript -path "install.log" -append
        } else {
            Write-Warning "This is being executed from PowerShell ISE so there is no transcript at install.log`r`n"
        }

        Install-Chocolatey
        Install-WebPI

        &$script

        $temp = [IO.Path]::GetTempPath()
        Write-Warning "Clear out $temp`r`n"

        if ($InTranscript) {
            Stop-Transcript
        }
    } catch {
        $Host.UI.WriteErrorLine($_)
        Write-Output "`r`n"
        if ($InTranscript) {
            Stop-Transcript
        }
        exit 1
    }
}

function Install-Chocolatey() {
    try {
        (iex "clist -lo") -Replace "^Reading environment variables.+$","" | Set-Variable -Name "installedPackages" -Scope Global
        Write-Output "cinst already installed with the following packages:`r`n"
        Write-Output $global:installedPackages
        Write-Output "`r`n"
    }
    catch {
        Write-Output "Installing Chocolatey`r`n"
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

function Install-WebPI() {
    if ($global:installedPackages -match "^webpicmd \d") {
        Write-Output "webpicmd already installed`r`n"
    } else {
        cinst webpicmd -Version 7.1.1374 | Out-Default # Latest version has a bug
    }
}

function Start-Script() {
    # http://blogs.msdn.com/b/powershell/archive/2007/06/19/get-scriptdirectory.aspx
    $invocation = (Get-variable -Name MyInvocation -Scope 2).Value
    $scriptpath = Split-Path $invocation.MyCommand.Path;
    Set-Variable -Name scriptpath -Value $scriptpath -Scope Global
    Invoke-Expression "cd $scriptpath"

    # Stop on errors
    Set-Variable -Name ErrorActionPreference -Value "stop" -Scope Global
}

function Get-SourcePath() {
    return (Get-variable -Name scriptpath -Scope Global).Value
}

function Test-Administrator() {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    return (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Test-VirtualMachine() {
    $objWMI = Get-WmiObject Win32_BaseBoard
    return ($objWMI.Manufacturer.Tolower() -match 'microsoft') -or ($objWMI.Manufacturer.Tolower() -match 'vmware')
}

function Set-AdvancedWindowsExplorerOptions() {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    
    if (($key | Get-ItemProperty -Name "Hidden").Hidden -ne 1) {
        Set-ItemProperty $key Hidden 1
        Set-ItemProperty $key HideFileExt 0
        Set-ItemProperty $key ShowSuperHidden 1
        Stop-Process -processname explorer
    }
}

function Install-EncryptingFilesystemCert($pfx, $rootPfx) {
    Write-Output "Installing encrypted filesystem cert`r`n"
    $password = Read-Host -AsSecureString "Enter the Encryption.pfx password"
    Import-PfxCertificate -FilePath $pfx cert:\CurrentUser\My -Exportable -Password $password
    Import-PfxCertificate -FilePath $rootPfx cert:\CurrentUser\TrustedPeople -Exportable -Password $password
}

function Install-IntelRST() {
    if (-not (Test-Path "C:\Program Files\Intel\Intel(R) Rapid Storage Technology")) {
        Write-Output "Installing Intel Rapid Storage Technology`r`n"
        if (-not (Test-Path Installers\SetupRST.exe)) {
            (new-object net.webclient).DownloadFile('http://downloadmirror.intel.com/23496/eng/SetupRST.exe', 'Installers\SetupRST.exe')
        }
        Start-Process -FilePath Installers\SetupRST.exe -ArgumentList "/quiet" -Wait
        Write-Warning "Check http://files.thecybershadow.net/trimcheck/trimcheck-0.6.exe`r`n"
    }
}

function Install-Git() {
    Install-ChocolateyPackage TortoiseGit
    Install-ChocolateyPackage poshgit
    Add-ToPath "C:\Program Files (x86)\Git\bin"
    if ((Test-Path ".ssh") -and (-not (Test-Path "~\.ssh"))) {
        Write-Output "Copying .ssh to ~`r`n"
        cp .ssh $env:userprofile -Recurse
        Set-TortoiseGitToUseSshKeys
    }
    if ((Test-Path ".gitconfig") -and (-not (Test-Path "~\.gitconfig"))) {
        Write-Output "Copying .gitconfig to ~`r`n"
        cp .gitconfig $env:userprofile -Recurse
    }
}

function Install-IIS() {
    if (-not (Test-Path "c:\inetpub")) {
        cinst IIS-WebServerRole -Source WindowsFeatures | Out-Default
    } else {
        Write-Output "IIS already installed`r`n"
    }
}

function Install-WebDeploy35() {
    if (-not (Test-Path "C:\Program Files\IIS\Microsoft Web Deploy V3")) {
        cmd.exe /c "webpicmd /Install /AcceptEula /SuppressReboot /Products:WDeployPS" 2>&1 | Out-Default
    } else {
        Write-Output "WebDeploy 3.5 already installed`r`n"
    }
}

function Install-VisualStudio2013($product, $features, $onInstall) {
    if ($product -eq $null) {
        $product = "Professional"
    }
    if ($features -eq $null) {
        $features = "WebTools SQL Win8SDK Win81SDK WindowsPhone80 WindowsPhone81 OfficeDeveloperTools Blend LightSwitch"
    }
    Install-ChocolateyPackage "VisualStudio2013$product" "/Features:'$vsFeatures'"

    Write-Warning "Open Visual Studio and log in with MSDN credentials`r`n"
    if ($onInstall -ne $null) {
        &$onInstall
    }
}

function Install-VisualStudio2013Iso($iso, $onInstall) {
    if (-not (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio 12.0")) {
        $iso = Join-Path Get-SourcePath $iso
        Write-Output "Installing VS Ultimate 2013 from .iso`r`n"
        $mount = Mount-DiskImage $iso -PassThru | Get-Volume
        Start-Process -FilePath "$($mount.DriveLetter):\vs_ultimate.exe" -ArgumentList "/passive /norestart" -Wait
        Dismount-DiskImage $iso

        Write-Warning "Open Visual Studio and log in with MSDN credentials`r`n"
        if ($onInstall -ne $null) {
            &$onInstall
        }
    } else {
        Write-Output "VS2013 already installed`r`n"
    }
}

function Restore-ReSharperExtensions($pathToPackagesConfig) {
    if (-not (Test-Path "$env:APPDATA\JetBrains\ReSharper\vAny\packages.config")) {
        Write-Output "Adding $pathToPackagesConfig to ReSharper`r`n"
        mkdir "$env:APPDATA\JetBrains\ReSharper\vAny" -ErrorAction SilentlyContinue | Out-Null
        cp $pathToPackagesConfig "$env:APPDATA\JetBrains\ReSharper\vAny"
        Write-Warning "Open ReSharper Extension Manager and click to restore packages`r`n"
    } else {
        Write-Output "ReSharper extensions already installed`r`n"
    }
}

function Install-AzureSDK2.3() {
    if (-not (Test-Path "C:\Program Files\Microsoft SDKs\Windows Azure\.NET SDK\v2.3")) {
        cmd.exe /c "webpicmd /Install /AcceptEula /SuppressReboot /Products:WindowsAzureSDK_2_3,VWDOrVs2013AzurePack.2.3,WindowsAzurePowershell" 2>&1 | Out-Default
    } else {
        Write-Output "Windows Azure SDK 2.3 already installed`r`n"
    }
}

function Install-Office2013Iso($iso, $msp) {
    if (-not (Test-Path "C:\Program Files\Microsoft Office\Office15")) {
        $iso = Join-Path Get-SourcePath $iso
        $msp = Join-Path Get-SourcePath $msp
        Write-Output "Installing Office 2013 Professional Plus from .iso`r`n"
        $mount = Mount-DiskImage $iso -PassThru | Get-Volume
        Start-Process -FilePath "$($mount.DriveLetter):\setup.exe" -ArgumentList "/adminfile ""$msp""" -Wait
        Dismount-DiskImage $iso
        Write-Warning "Open Office program and enter product key`r`n"
    } else {
        Write-Output "Office 2013 already installed`r`n"
    }
}

function Install-OutlookSignatures($signaturesPath) {
    if (-not (Test-Path "$env:APPDATA\Microsoft\Signatures")) {
        Write-Output "Copying in Outlook signatures`r`n"
        cp $signaturesPath "$env:APPDATA\Microsoft" -Recurse
    } else {
        Write-Output "Outlook signatures already installed`r`n"
    }
}

function Add-ToPath($path) {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    if ($env:PATH.indexOf($path) -eq -1) {
        Write-Output "Updating PATH to include $path`r`n"
        setx PATH "$env:PATH;$path" -m
    }
}

function Set-TortoiseGitToUseSshKeys() {
    Write-Output "Configuring TortoiseGit to use SSH rather than PLink`r`n"
    Set-ItemProperty "HKCU:\Software\TortoiseGit" SSH "C:\Program Files (x86)\Git\bin\ssh.exe"
}

function Set-TaskBarPin($path, $exe) {
    if (Test-Path "$path\$exe") {
        Write-Output "Pinning $path\$exe to the taskbar`r`n"
        $shell = new-object -com "Shell.Application"  
        $folder = $shell.Namespace($path)    
        $item = $folder.Parsename($exe)
        $item.invokeverb("taskbarpin")
    }
}

function Set-TaskBarPinChrome() {
    Set-TaskBarPin "C:\Program Files (x86)\Google\Chrome\Application" "chrome.exe"
}
function Set-TaskBarPinOutlook2013() {
    Set-TaskBarPin "C:\Program Files\Microsoft Office\Office15" "outlook.exe"
}
function Set-TaskBarPinVisualStudio2013() {
    Set-TaskBarPin "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE" "devenv.exe"
}
function Set-TaskBarPinLinqpad4() {
    Set-TaskBarPin "C:\Program Files (x86)\LINQPad4" "linqpad.exe"
}
function Set-TaskBarPinLync2013() {
    Set-TaskBarPin "C:\Program Files\Microsoft Office\Office15" "lync.exe"
}
function Set-TaskBarPinOneNote2013() {
    Set-TaskBarPin "C:\Program Files\Microsoft Office\Office15" "onenote.exe"
}
function Set-TaskBarPinRDP() {
    Set-TaskBarPin "C:\Windows\system32" "mstsc.exe"
}
function Set-TaskBarPinSSMS() {
    Set-TaskBarPin "C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio" "Ssms.exe"
}
function Set-TaskBarPinPaintDotNet() {
    Set-TaskBarPin "C:\Program Files\Paint.NET" "PaintDotNet.exe"
}

function Install-VSExtension($vsixUrl) {
    Write-Output "Installing VS extension: $vsixUrl`r`n"
    $vsixPath = Join-Path ([IO.Path]::GetTempPath()) ($vsixUrl.Substring($vsixUrl.LastIndexOf("/") + 1))

    (new-object net.webclient).DownloadFile($vsixUrl, $vsixPath)
    Start-Process -FilePath "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\VSIXInstaller.exe" -ArgumentList """$vsixPath"" /quiet" -Wait -RedirectStandardOutput -RedirectStandardError
}

function Install-ChocolateyPackage {
    [CmdletBinding()]
    Param (
        [String]$PackageName,
        [String]$InstallArgs,
        $RunIfInstalled
    )

    if ($global:installedPackages -match "^$PackageName \d") {
        Write-Output "$PackageName already installed`r`n"
    } else {
        if ($InstallArgs -ne $null) {
            Write-Output "cinst $PackageName -InstallArguments ""$InstallArgs""`r`n"
            iex "cinst $PackageName -InstallArguments ""$InstallArgs""" | Out-Default
        } else {
            Write-Output "cinst $PackageName`r`n"
            iex "cinst $PackageName" | Out-Default
        }

        if ($RunIfInstalled -ne $null) {
            &$RunIfInstalled
        }
    }
}

function Install-ITunesMusicLibrary($pathToMusicLibrary) {
    if (-not (Test-Path "~\Music\iTunes")) {
        Write-Output "Copying in iTunes library`r`n"
        cp $pathToMusicLibrary "~\Music" -Recurse
    } else {
        Write-Output "iTunes library already installed`r`n"
    }
}

function Install-AzureManagementStudio() {
    if (-not (Test-Path "$env:APPDATA\Cerebrata\AzureManagementStudio")) {
        Write-Output "Installing Azure Management Studio`r`n"
        if (-not (Test-Path "Installers\AzureManagementStudio.exe")) {
            # todo: Why isn't this working?
            (new-object net.webclient).DownloadFile("http://installers.cerebrata.com/setup/Azure%20Management%20Studio/production/1/Azure%20Management%20Studio.exe", "Installers\AzureManagementStudio.exe")
        }
        & Installers\AzureManagementStudio.exe | Out-Default
        # todo: get this to actually install
        Write-Warning "Add Azure Management Studio license key"
    } else {
        Write-Output "Azure Management Studio already installed`r`n"
    }
}

function Install-HyperV() {
    if (-not (Test-Path "C:\Program Files\Hyper-V")) {
        cinst Microsoft-Hyper-V -Source WindowsFeatures | Out-Default
    } else {
        Write-Output "HyperV already installed`r`n"
    }
}

function Install-SQLServerExpress2014AndManagementStudio() {
    if (-not (Test-Path "C:\Program Files\Microsoft SQL Server\MSSQL12.SQLEXPRESS")) {
        Write-Output "Installing SQL Server 2014 Express`r`n"
        if (Test-Path "Installers\SQLEXPRWT_x64_ENU\setup.exe") {
            Installers\SQLEXPRWT_x64_ENU\setup.exe /QUIETSIMPLE /ACTION=install /FEATURES=SQL,Tools /IAcceptSQLServerLicenseTerms
        } else {
            throw "Download http://care.dlservice.microsoft.com/dl/download/E/A/E/EAE6F7FC-767A-4038-A954-49B8B05D04EB/SQLEXPRWT_x64_ENU.exe and extract to Installers\SQLEXPRWT_x64_ENU"
        }
    } else {
        Write-Output "SQL Server 2014 Express already installed`r`n"
    }
}

Export-ModuleMember -Function *