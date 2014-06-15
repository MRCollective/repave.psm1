repave.ps1
==========

A PowerShell module that allows you to easily create a terse re-pave script for a Windows Machine making heavy use of Chocolatey.

It focusses on speed and idempotency allowing you to add to the script as you go about the business of adding software to your machine. That way when it comes time to do the next repave it's good to go rather than having to spend half a day figuring out the missing software. If something is already installed then it will immediately skip it rather than invoking `cinst` to find out meaning the script should fly through to the end if you are simply adding a new installation at the bottom.

Look at `robdmoore.ps1` or `MattDavies.ps1` for examples of how to use the scripts. These are the scripts that we actually use for our machines.

Feel free to fork this and add your own script. Also feel free to send pull requests or raise issues if you have ideas / questions.

Get us via Twitter at: [@robdmoore](http://twitter.com/robdmoore) / [@mdaviesnet](http://twitter.com/mdaviesnet).

Minimum example
---------------

To get started all you need is this in a `.ps1` file:

```powershell
Import-Module "$(Split-Path $MyInvocation.MyCommand.Path)\install.psm1" -Force
Invoke-Repave {
    # Stuff to install
}
```

When you run it you must be in admin mode and after running there will be an `install.log` file with the output and any warnings for further action (unless you ran the script from PowerShell ISE, in which case there is no transcript).
