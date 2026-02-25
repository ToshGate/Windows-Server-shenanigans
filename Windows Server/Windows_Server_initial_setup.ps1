# Check if running as Administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    # Relaunch script as Administrator
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Script continues here with Admin privileges

# Define the registry path
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"

# Create the key if it doesn't exist
If (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Show "This PC" on desktop (set value to 0)
Set-ItemProperty -Path $regPath -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0

# --- Set DEP ---
bcdedit.exe /set {current} nx OptIn

# --- Set File Explorer to open in This PC ---
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "LaunchTo" -Value 1

# --- Hide Search Bar ---
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "SearchboxTaskbarMode" -Value 0

# --- Set Windows Mode (Dark) & App Mode (Light) ---
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "SystemUsesLightTheme" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
    -Name "AppsUseLightTheme" -Value 1

# --- Set Power Plan to High Performance ---
$highPerf = powercfg -l | Where-Object { $_ -match "High performance" } | ForEach-Object {
    ($_ -split '\s+')[3]
}
if ($highPerf) {
    powercfg -setactive $highPerf
} else {
    $newPlan = powercfg -duplicatescheme SCHEME_MIN
    powercfg -setactive $newPlan
}

# --- Restart Explorer silently ---
Stop-Process -Name explorer -Force
Start-Process explorer