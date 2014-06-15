param(
 [string]$newInstall = "false"
)

function Test-Administrator() {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    return (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Test-VirtualMachine() {
    $objWMI = Get-WmiObject Win32_BaseBoard
    return ($objWMI.Manufacturer.Tolower() -match 'microsoft') -or ($objWMI.Manufacturer.Tolower() -match 'vmware')
}

function Set-ExplorerOptions() {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    
    if (($key | Get-ItemProperty -Name "Hidden").Hidden -ne 1) {
        Set-ItemProperty $key Hidden 1
        Set-ItemProperty $key HideFileExt 0
        Set-ItemProperty $key ShowSuperHidden 1
        Stop-Process -processname explorer
    }
}

function Set-TortoiseGitToUseSshKeys() {
    Write-Output "Configuring TortoiseGit to use SSH rather than PLink`r`n"
    Set-ItemProperty "HKCU:\Software\TortoiseGit" SSH "C:\Program Files\TortoiseGit\bin\ssh.exe"
}

function Set-TaskBarPin($path, $exe) {
    $shell = new-object -com "Shell.Application"  
    $folder = $shell.Namespace($path)    
    $item = $folder.Parsename($exe)
    $item.invokeverb("taskbarpin")
}

function Install-VSExtension($vsixUrl) {
    Write-Output "Installing VS extension: $vsixUrl`r`n"
    $vsixPath = Join-Path ([IO.Path]::GetTempPath()) ($vsixUrl.Substring($vsixUrl.LastIndexOf("/") + 1))

    (new-object net.webclient).DownloadFile($vsixUrl, $vsixPath)
    Start-Process -FilePath "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\VSIXInstaller.exe" -ArgumentList """$vsixPath"" /quiet" -Wait -RedirectStandardOutput -RedirectStandardError
}

function Install-ChocolateyPackage($packageName, $installArgs) {

    if ($global:installedPackages -match "^$packageName \d") {
        Write-Output "$packageName already installed`r`n"
    } elseif ($installArgs -ne $null) {
        Write-Output "cinst $packageName -InstallArguments ""$installArgs""`r`n"
        iex "cinst $packageName -InstallArguments ""$installArgs""" | Out-Default
    } else {
        Write-Output "cinst $packageName`r`n"
        iex "cinst $packageName" | Out-Default
    }
}

function Start-AndLogProcess($exe, $args) {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $exe
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $args
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start()
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    Write-Output $stdout

    if ($p.ExitCode -ne 0) {
        throw $stderr
    }
}

$ErrorActionPreference = "Stop"
$InTranscript = $Host.Name -ne "Windows PowerShell ISE Host"
if ($InTranscript) {
    Start-Transcript -path "install.log" -append
}

$isRob = [Environment]::UserName -match "Rob"

$vsEdition = "Professional";
$vsFeatures = "WebTools" # Space-separated - WebTools SQL Win8SDK Win81SDK WindowsPhone80 WindowsPhone81 OfficeDeveloperTools Blend LightSwitch
$installEncryptionCert = $false;
$installIntelRst = $false;

if ($isRob) {
    $vsEdition = "Ultimate";
    $installIntelRst = -not (Test-VirtualMachine);
}

if ($newInstall -eq "true") {
    Write-Warning "Have you Bitlocker encrypted the drive?`r`n"
    Read-Host
    $installEncryptionCert = $true;
}


$scriptpath = Split-Path $MyInvocation.MyCommand.Path
cd $scriptpath
mkdir Installers -ErrorAction SilentlyContinue | Out-Null

try
{
    if (-not (Test-Administrator)) {
        Write-Error "Open in admin mode`r`n"
        exit 1
    }

    # Windows Explorer
    Set-ExplorerOptions

    # Chocolatey
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

    # Encryption.pfx
    if ($installEncryptionCert -and (Test-Path "Encryption.pfx")) {
        Write-Output "Installing encrypted filesystem cert`r`n"
        $password = Read-Host -AsSecureString "Enter the Encryption.pfx password"
        Import-PfxCertificate -FilePath Encryption.pfx cert:\CurrentUser\My -Exportable -Password $password
        Import-PfxCertificate -FilePath EncryptionRoot.pfx cert:\CurrentUser\TrustedPeople -Exportable -Password $password
    }
    
    # SSD
    if ($installIntelRst -and (-not (Test-Path "C:\Program Files\Intel\Intel(R) Rapid Storage Technology"))) {
        Write-Output "Installing Intel Rapid Storage Technology`r`n"
        if (-not (Test-Path Installers\SetupRST.exe)) {
            (new-object net.webclient).DownloadFile('http://downloadmirror.intel.com/23496/eng/SetupRST.exe', 'Installers\SetupRST.exe')
        }
        Start-Process -FilePath Installers\SetupRST.exe -ArgumentList "/quiet" -Wait -RedirectStandardOutput -RedirectStandardError
        Write-Warning "Check http://files.thecybershadow.net/trimcheck/trimcheck-0.6.exe`r`n"
    }

    # Git
    Install-ChocolateyPackage TortoiseGit
    Install-ChocolateyPackage poshgit
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    if ($env:PATH.indexOf("C:\Program Files (x86)\Git\bin") -eq -1) {
        Write-Output "Updating PATH to include git\bin`r`n"
        setx PATH "$env:PATH;C:\Program Files (x86)\Git\bin" -m
    }
    if ((Test-Path ".ssh") -and (-not (Test-Path "~\.ssh"))) {
        Write-Output "Copying .ssh to ~`r`n"
        cp .ssh $env:userprofile -Recurse
        Set-TortoiseGitToUseSshKeys
    }
    if ((Test-Path ".gitconfig") -and (-not (Test-Path "~\.gitconfig"))) {
        Write-Output "Copying .gitconfig to ~`r`n"
        cp .gitconfig $env:userprofile -Recurse
    }

    # IIS
    if (-not (Test-Path "c:\inetpub")) {
        cinst IIS-WebServerRole -Source WindowsFeatures | Out-Default
    } else {
        Write-Output "IIS already installed`r`n"
    }
    Install-ChocolateyPackage UrlRewrite
    if ($global:installedPackages -match "^webpicmd \d") {
        Write-Output "webpicmd already installed`r`n"
    } else {
        cinst webpicmd -Version 7.1.1374 | Out-Default # Latest version has a bug
    }
    if (-not (Test-Path "C:\Program Files\IIS\Microsoft Web Deploy V3")) {
        cmd.exe /c "webpicmd /Install /AcceptEula /SuppressReboot /Products:WDeployPS" 2>&1 | Out-Default
    } else {
        Write-Output "WebDeploy 3.5 already installed`r`n"
    }
    
    # Visual Studio
    if (-not (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio 12.0")) {
        if ($vsEdition -eq "Ultimate") {
            $iso = "$scriptpath\isos\en_visual_studio_ultimate_2013_with_update_2_x86_dvd_4238214.iso"
            if (Test-Path $iso) {
                Write-Output "Installing VS Ultimate 2013 from .iso`r`n"
                $mount = Mount-DiskImage $iso -PassThru | Get-Volume
                Start-Process -FilePath "$($mount.DriveLetter):\vs_ultimate.exe" -ArgumentList "/passive /norestart" -Wait
                Dismount-DiskImage $iso
            } else {
                Install-ChocolateyPackage "VisualStudio2013Ultimate" "/Features:'$vsFeatures'"
            }
        } else {
            Install-ChocolateyPackage "VisualStudio2013Professional" "/Features:'$vsFeatures'"
        }

        Write-Warning "Open Visual Studio and log in with MSDN credentials`r`n"
        Install-VSExtension "http://visualstudiogallery.msdn.microsoft.com/6a2ae0fa-bd4e-4712-9170-abe92c63c05c/file/109467/20/MattDavies.TortoiseGitToolbar.vsix"
        Install-VSExtension "http://visualstudiogallery.msdn.microsoft.com/1f6ec6ff-e89b-4c47-8e79-d2d68df894ec/file/37912/30/RazorGenerator.vsix"
        Install-VSExtension "http://visualstudiogallery.msdn.microsoft.com/71a4e9bd-f660-448f-bd92-f5a65d39b7f0/file/52593/29/chutzpah.visualstudio.vsix"
        Install-VSExtension "http://visualstudiogallery.msdn.microsoft.com/f8741f04-bae4-4900-81c7-7c9bfb9ed1fe/file/66979/24/Chutzpah.VS2012.vsix"
    } else {
        Write-Output "VSUltimate already installed`r`n"
    }
    Install-ChocolateyPackage VS2013.VSCommands
    Install-ChocolateyPackage XUnit.VisualStudio
    Install-ChocolateyPackage ReSharper
    if (Test-Path packages.config) {
        if (-not (Test-Path "$env:APPDATA\JetBrains\ReSharper\vAny\packages.config")) {
            Write-Output "Adding packages.config to ReSharper`r`n"
            mkdir "$env:APPDATA\JetBrains\ReSharper\vAny" -ErrorAction SilentlyContinue | Out-Null
            cp packages.config "$env:APPDATA\JetBrains\ReSharper\vAny"
            Write-Warning "Open ReSharper Extension Manager and click to restore packages`r`n"
        } else {
            Write-Output "ReSharper extensions already installed`r`n"
        }
    }
    
    # Azure SDK
    if (-not (Test-Path "C:\Program Files\Microsoft SDKs\Windows Azure\.NET SDK\v2.3")) {
        cmd.exe /c "webpicmd /Install /AcceptEula /SuppressReboot /Products:WindowsAzureSDK_2_3,VWDOrVs2013AzurePack.2.3,WindowsAzurePowershell" 2>&1 | Out-Default
    } else {
        Write-Output "Windows Azure SDK 2.3 already installed`r`n"
    }
    
    # Utils
    Install-ChocolateyPackage fiddler4
    Install-ChocolateyPackage sysinternals
    Install-ChocolateyPackage windirstat
    Install-ChocolateyPackage 7zip
    Install-ChocolateyPackage AdobeReader
    if ($isRob) {
        Install-ChocolateyPackage vim
    } else {
        Install-ChocolateyPackage notepadplusplus
        Install-ChocolateyPackage vlc
    }
    Write-Warning "Install Cisco AnyConnect, Photoshop`r`n"
    
    # Internet
    Install-ChocolateyPackage GoogleChrome
    Install-ChocolateyPackage Firefox
    Write-Warning "Set Firefox to not auto-update if using for Selenium testing`r`n"
    Install-ChocolateyPackage Skype
    Install-ChocolateyPackage Dropbox

    # Office
    $iso = "$scriptpath\isos\SW_DVD5_Office_Professional_Plus_2013_64Bit_English_MLF_X18-55297.iso"
    if (-not (Test-Path "C:\Program Files\Microsoft Office\Office15")) {
        if (Test-Path $iso) {
            Write-Output "Installing Office 2013 Professional Plus from .iso`r`n"
            $mount = Mount-DiskImage $iso -PassThru | Get-Volume
            Start-Process -FilePath "$($mount.DriveLetter):\setup.exe" -ArgumentList "/adminfile ""$scriptpath\office2013.msp""" -Wait
            Dismount-DiskImage $iso
            Write-Warning "Open Office program and enter product key`r`n"
        }
    } else {
        Write-Output "Office 2013 already installed`r`n"
    }
    if (Test-Path "Signatures") {
        cp Signatures "$env:APPDATA\Microsoft" -Recurse
    }

    # Pin to taskbar
    
    # Final warnings
    $temp = [IO.Path]::GetTempPath()
    Write-Warning "Clear out $temp`r`n"
    Write-Warning "Check device manager for missing drivers; check graphics drivers; check laptop special buttons work`r`n"
    Write-Warning "Configure power options`r`n"

    if ($InTranscript) {
        Stop-Transcript
    }
}
catch
{
    $Host.UI.WriteErrorLine($_)
    Write-Output "`r`n"
    if ($InTranscript) {
        Stop-Transcript
    }
    exit 1
}