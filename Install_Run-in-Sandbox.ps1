# TLS 1.2 aktivieren, falls noch nicht gesetzt
if ([Net.ServicePointManager]::SecurityProtocol -ne [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "TLS 1.2 wurde als Sicherheitsprotokoll gesetzt."
} else {
    Write-Host "TLS 1.2 ist aktiviert (:" -ForegroundColor Green
}

# Function to restart the script with admin rights
function Restart-ScriptWithAdmin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Skript ohne Admin-Rechte gestartet, starte neu mit Admin-Rechten!" -ForegroundColor Yellow
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -NoExit -Command `"(Invoke-webrequest -URI `"https://raw.githubusercontent.com/Joly0/Run-in-Sandbox/master/Install_Run-in-Sandbox.ps1`").Content | Invoke-Expression`"" -Verb RunAs
        #Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File 'C:\temp\PreInstallCheck.ps1'" -Verb RunA
        exit
    } else {
    Write-Host "Skript als Admin gestartet (:" -ForegroundColor Green
    }
}

# Restart the script with admin rights if not already running as admin
Restart-ScriptWithAdmin

# Funktion zur Prüfung der Voraussetzungen
function CheckPrerequisites {
    Write-Host "Check System requirements..."

    # RAM prüfen
    $ramGB = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    if ($ramGB -lt 4) {
        Write-Error "Not enough RAM: found $ramGB GB, min. 4 GB requiered."
        #Pause
        #exit 1
    }

    # Speicherplatz prüfen
    $diskFreeGB = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 2)
    if ($diskFreeGB -lt 1) {
        Write-Error "Nicht genuegend freier Speicherplatz: $diskFreeGB GB gefunden, mindestens 1 GB erforderlich."
        #Pause
        #exit 1
    }

    # Hyper-V und Sandbox prüfen
    $hyperv = dism /online /get-featureinfo /featurename:Microsoft-Hyper-V-All | Out-String
    $sandbox = dism /online /get-featureinfo /featurename:Containers-DisposableClientVM | Out-String
    $hypervEnabled = $hyperv -match "State : Enabled"
    $sandboxEnabled = $sandbox -match "State : Enabled"

    if (-not $hypervEnabled -or -not $sandboxEnabled) {
        Write-Warning "Hyper-V oder Windows Sandbox ist nicht aktiviert."
        $response = Read-Host "Moechten Sie Hyper-V und Windows Sandbox aktivieren und den PC neu starten? (J/N)"
        if ($response -eq "J") {
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart -All
            Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -NoRestart -All
            Write-Host "Features wurden aktiviert. Der PC wird jetzt neu gestartet..."
            Restart-Computer
            Write-Host "Bitte führen Sie das Skript nach dem Neustart erneut aus." -ForegroundColor Magenta
            Start-Sleep 6
            exit 0
        } else {
            Write-Host "Installation abgebrochen. Bitte aktivieren Sie die erforderlichen Features manuell." -ForegroundColor Yellow
            Start-Sleep 6
            exit 1
        }
    }

    Write-Host "Alle Voraussetzungen erfüllt. Installation kann fortgesetzt werden."
}

# Funktion zum Offenhalten des Fensters
function Pause {
    Write-Host "Druecken Sie eine Taste, um fortzufahren..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Führe die Prüfung aus
CheckPrerequisites

# Define the URL and file paths
$zipUrl = "https://github.com/henrikmai/Run-in-Sandbox/archive/refs/heads/master.zip"
$tempPath = [System.IO.Path]::GetTempPath()
$zipPath = Join-Path -Path $tempPath -ChildPath "master.zip"
$extractPath = Join-Path -Path $tempPath -ChildPath "Run-in-Sandbox-master"


# Remove existing extracted folder if it exists
if (Test-Path $extractPath) {
    try {
        Write-Host "Removing existing extracted folder..."
        Remove-Item -Path $extractPath -Recurse -Force
        Write-Host "Existing extracted folder removed."
    } catch {
        Write-Error "Failed to remove existing extracted folder: $_"
        exit 1
    }
}

# Download the zip file
try {
    Write-Host "Downloading zip file..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "Download completed."
} catch {
    Write-Error "Failed to download the zip file: $_"
    exit 1
}

# Extract the zip file
try {
    Write-Host "Extracting zip file..."
    $ProgressPreference = 'SilentlyContinue'
    Expand-Archive -Path $zipPath -DestinationPath $tempPath
    $ProgressPreference = 'Continue'
    Write-Host "Extraction completed."
} catch {
    Write-Error "Failed to extract the zip file: $_"
    exit 1
}

# Remove the zip file
try {
    Write-Host "Removing zip file..."
    Remove-Item -Path $zipPath
    Write-Host "Zip file removed."
} catch {
    Write-Error "Failed to remove the zip file: $_"
    exit 1
}

# Construct the path to the add_structure.ps1 script
$addStructureScript = Join-Path -Path $extractPath -ChildPath "Add_Structure.ps1"

# Set Execution Policy and unblock files
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted
Get-ChildItem -LiteralPath $extractPath -Filter "*.ps1" | Unblock-File

# Execute the add_structure.ps1 script with the "-NoCheckpoint" parameter if it was provided
try {
    Write-Host "Executing Add_Structure.ps1 script..."
    if ($NoCheckpoint) {
        & $addStructureScript -NoCheckpoint
    } else {
        & $addStructureScript
    }
    Write-Host "Script execution completed."
} catch {
    Write-Error "Failed to execute add_structure.ps1: $_"
    exit 1
}

Read-Host "Installation finished. Press Enter to exit."
