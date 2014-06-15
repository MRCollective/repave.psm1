1. Check out these three files: `install.ps1`, `packages.config`, `.gitconfig`
2. Drop in `Encryption.pfx` and `EncryptionRoot.pfx` (both with same password) if you want to install an encrypting filesystem cert - you will be prompted to enter the password (it won't be shown on screen)
3. Drop in a `.ssh` folder if you want private keys dropped into your `~` directory
4. Drop in a `Signatures` folder if you want Outlook signatures copied in
5. Drop in `isos\en_visual_studio_ultimate_2013_with_update_2_x86_dvd_4238214.iso` if you want to install VS from iso rather than downloading over the Internet
6. Drop in `isos\SW_DVD5_Office_Professional_Plus_2013_64Bit_English_MLF_X18-55297.iso` if you want to install Office 2013
7. Run `install.ps1` as admin
8. There will be a `install.log` file with the output and any warnings for further action (unless you ran the script from PowerShell ISE)
9. Enjoy!
