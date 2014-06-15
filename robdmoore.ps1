param(
 [string]$update = "false"
)
if ($update -eq "false") {
    Write-Warning "Have you Bitlocker encrypted the drive?`r`n"
    Read-Host
}

Import-Module "$(Split-Path $MyInvocation.MyCommand.Path)\repave.psm1" -Force
Invoke-Repave {

    # Windows Explorer
    Set-AdvancedWindowsExplorerOptions

    # Encryption.pfx
    if ($update -eq "false") {
        Install-EncryptingFilesystemCert Encryption.pfx EncryptionRoot.pfx
    }
    
    # SSD
    if (-not (Test-VirtualMachine)) {
        Install-IntelRST
    }

    # Git
    Install-Git

    # IIS
    Install-IIS
    Install-ChocolateyPackage UrlRewrite
    
    # Visual Studio
    Install-VisualStudio2013Iso "isos\en_visual_studio_ultimate_2013_with_update_2_x86_dvd_4238214.iso" {
        Install-VS2013Extension "http://visualstudiogallery.msdn.microsoft.com/6a2ae0fa-bd4e-4712-9170-abe92c63c05c/file/109467/20/MattDavies.TortoiseGitToolbar.vsix"
        Install-VS2013Extension "http://visualstudiogallery.msdn.microsoft.com/1f6ec6ff-e89b-4c47-8e79-d2d68df894ec/file/37912/30/RazorGenerator.vsix"
        Install-VS2013Extension "http://visualstudiogallery.msdn.microsoft.com/71a4e9bd-f660-448f-bd92-f5a65d39b7f0/file/52593/29/chutzpah.visualstudio.vsix"
        Install-VS2013Extension "http://visualstudiogallery.msdn.microsoft.com/f8741f04-bae4-4900-81c7-7c9bfb9ed1fe/file/66979/24/Chutzpah.VS2012.vsix"
        Install-VS2013Extension "http://visualstudiogallery.msdn.microsoft.com/c6d1c265-7007-405c-a68b-5606af238ece/file/106247/16/SquaredInfinity.VSCommands.VS12.vsix"
    }
    Install-ChocolateyPackage XUnit.VisualStudio
    Install-ChocolateyPackage ReSharper
    Restore-ReSharperExtensions "packages.config"

    # Web Deploy
    Install-WebDeploy35
    
    # Azure SDK
    Install-AzureSDK2.3
    Install-AzureManagementStudio
    
    # Utils
    Install-ChocolateyPackage fiddler4
    Install-ChocolateyPackage sysinternals
    Install-ChocolateyPackage windirstat
    Install-ChocolateyPackage 7zip
    Install-ChocolateyPackage AdobeReader
    Install-ChocolateyPackage vim
    Install-ChocolateyPackage lockhunter
    Install-ChocolateyPackage paint.net
    Install-ChocolateyPackage linqpad4 -RunIfInstalled { Write-Warning "Register linqpad via: LINQPad.exe -activate=PRODUCT_CODE`r`n" }
    
    # Internet
    Install-ChocolateyPackage GoogleChrome
    Install-ChocolateyPackage Firefox -RunIfInstalled { Write-Warning "Set Firefox to not auto-update if using for Selenium testing`r`n" }
    Install-ChocolateyPackage Skype
    Install-ChocolateyPackage Dropbox
    Install-ChocolateyPackage lastpass

    # Office
    Install-Office2013Iso "isos\SW_DVD5_Office_Professional_Plus_2013_64Bit_English_MLF_X18-55297.iso" "office2013.msp"
    Install-OutlookSignatures "Signatures"

    # Other
    Install-ChocolateyPackage steam -RunIfInstalled { Write-Warning "Restore game backups and save games" }
    Install-ChocolateyPackage nodejs.install
    Install-ChocolateyPackage ruby
    Install-ITunesMusicLibrary "iTunes"
    Install-ChocolateyPackage iTunes
    if (-not (Test-VirtualMachine)) {
        Install-HyperV
    }
    Install-SQLServerExpress2014AndManagementStudio

    # Pin to taskbar
    Set-TaskBarPinChrome
    Set-TaskBarPinOutlook2013
    Set-TaskBarPinVisualStudio2013
    Set-TaskBarPinLinqpad4
    Set-TaskBarPinLync2013
    Set-TaskBarPinOneNote2013
    Set-TaskBarPinRDP
    Set-TaskBarPinSSMS
    Set-TaskBarPinPaintDotNet
    
    # Final warnings
    if ($update -eq "false") {
        Write-Warning "Check device manager for missing drivers; check graphics drivers; check laptop special buttons work`r`n"
        Write-Warning "Install printers"
        Write-Warning "Configure power options`r`n"
        Write-Warning "Run Windows Update`r`n"
    }
}
