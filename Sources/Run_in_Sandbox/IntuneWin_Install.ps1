param (
	[String]$Intunewin_Content_File = "C:\Run_in_Sandbox\Intunewin_Folder.txt",
	[String]$Intunewin_Command_File = "C:\Run_in_Sandbox\Intunewin_Install_Command.txt"
)
if (-not (Test-Path $Intunewin_Content_File) ) {
	EXIT
}
if (-not (Test-Path $Intunewin_Command_File) ) {
	EXIT
}

$Sandbox_Folder = "C:\Run_in_Sandbox"
$ScriptPath = Get-Content -Raw $Intunewin_Content_File
$Command = Get-Content -Raw $Intunewin_Command_File
$Command = $Command.replace('"','')

$FileName = (Get-Item $ScriptPath).BaseName

##########################################
# Create Folder for Intune Logs
New-item "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" -Force -Type Directory

# Create Shortcut to Log Folder

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:PUBLIC\Desktop\Intune Logs.lnk")
$Shortcut.TargetPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$Shortcut.WorkingDirectory = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$Shortcut.WindowStyle = 1
$Shortcut.Description = "Shortcut to Intune Management Extension Logs"
$Shortcut.Save()

# Register cmtrace as Log Viewer
# File Name Extensions
Set-Itemproperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -value 0

$ext = ".log"
$progId = "CMTrace.LogFile"
$cmtracePath = "C:\Run_in_Sandbox\cmtrace.exe"

# Register the file extension
New-Item -Path "HKCU:\Software\Classes\$ext" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$ext" -Name "(Default)" -Value $progId

# Register the ProgID
New-Item -Path "HKCU:\Software\Classes\$progId\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\$progId" -Name "(Default)" -Value "Log File"
Set-ItemProperty -Path "HKCU:\Software\Classes\$progId\shell\open\command" -Name "(Default)" -Value "`"$cmtracePath`" `"%1`""

# Optional: Refresh Explorer to apply changes
Stop-Process -Name explorer -Force


###########################################

$Intunewin_Extracted_Folder = "C:\Windows\Temp\intunewin"
New-Item -Path $Intunewin_Extracted_Folder -Type Directory -Force | Out-Null
Copy-Item -Path $ScriptPath -Destination $Intunewin_Extracted_Folder -Force
$New_Intunewin_Path = "$Intunewin_Extracted_Folder\$FileName.intunewin"

Set-Location -Path $Sandbox_Folder
& .\IntuneWinAppUtilDecoder.exe $New_Intunewin_Path -s
$IntuneWinDecoded_File_Name = "$Intunewin_Extracted_Folder\$FileName.decoded.zip"

New-Item -Path "$Intunewin_Extracted_Folder\$FileName" -Type Directory -Force | Out-Null

$IntuneWin_Rename = "$FileName.zip"

Rename-Item -Path $IntuneWinDecoded_File_Name -NewName $IntuneWin_Rename -Force

$Extract_Path = "$Intunewin_Extracted_Folder\$FileName"
Expand-Archive -LiteralPath "$Intunewin_Extracted_Folder\$IntuneWin_Rename" -DestinationPath $Extract_Path -Force

Remove-Item -Path "$Intunewin_Extracted_Folder\$IntuneWin_Rename" -Force
Start-Sleep -Seconds 1

$ServiceUI = "$Sandbox_Folder\ServiceUI.exe"
$PsExec = "$Sandbox_Folder\PsExec.exe"


& $PsExec \\localhost -w "$Extract_Path" -nobanner -accepteula -s $ServiceUI -Process:explorer.exe C:\windows\SysWOW64\cmd.exe /k $Command