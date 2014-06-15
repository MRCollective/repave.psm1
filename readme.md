1. Check out these four files: `install.ps1`, `packages.config`, `.gitconfig`, `office2013.msp`
2. Drop in `Encryption.pfx` and `EncryptionRoot.pfx` (both with same password) if you want to install an encrypting filesystem cert - you will be prompted to enter the password (it won't be shown on screen)
3. Drop in a `.ssh` folder if you want private keys dropped into your `~` directory
4. Drop in a `Signatures` folder if you want Outlook signatures copied in
5. Drop in a `iTunes` folder if you want it copied to your My Music folder
6. Drop in `isos\en_visual_studio_ultimate_2013_with_update_2_x86_dvd_4238214.iso` if you want to install VS from iso rather than downloading over the Internet
7. Drop in `isos\SW_DVD5_Office_Professional_Plus_2013_64Bit_English_MLF_X18-55297.iso` if you want to install Office 2013
8. Download [SQL Server 2014 Express](http://care.dlservice.microsoft.com/dl/download/E/A/E/EAE6F7FC-767A-4038-A954-49B8B05D04EB/SQLEXPRWT_x64_ENU.exe", "Installers\SQLEXPRWT_x64_ENU.exe) and run the installer and extract the files to `Installers/SQLEXPRWT_x64_ENU` if you want the script to install SQL Express and Management Studio
9. Run `install.ps1` as admin
10. There will be a `install.log` file with the output and any warnings for further action (unless you ran the script from PowerShell ISE)
11. Enjoy!
