# Check if running as Administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    # Relaunch script as Administrator
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Script continues here with Admin privileges

DISM /online /Get-CurrentEdition

DISM /online /Get-TargetEditions

DISM /online /Set-Edition:ServerDatacenter /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula

pause