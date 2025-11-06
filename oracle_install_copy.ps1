# --- 1. CONFIGURATION: ADJUST THESE VARIABLES ---

# Azure File Share Configuration
$AzureFileShareUNC = "\\teastasjay.file.core.windows.net\test\oracle"
$ZipFileName = "WINDOWS.X64_193000_client.zip"
$SourceZipPath = Join-Path -Path $AzureFileShareUNC -ChildPath $ZipFileName

# Response File Configuration 
$ResponseFileName = "client_silent.rsp"
$SourceRspPath = Join-Path -Path $AzureFileShareUNC -ChildPath $ResponseFileName # Source on File Share
# *** MODIFIED: Staging Response File to C:\Temp\ ***
$ResponseFilePath = Join-Path -Path "C:\Temp" -ChildPath $ResponseFileName 

# Local Staging Configuration
$DestinationTempPath = "C:\Temp"
$LocalZipPath = Join-Path -Path $DestinationTempPath -ChildPath $ZipFileName
$ExtractFolderName = "oracle12c"
$ExtractPath = Join-Path -Path $DestinationTempPath -ChildPath $ExtractFolderName
$SetupExePath = Join-Path -Path $ExtractPath -ChildPath "client\setup.exe" 

# Oracle Installer Configuration
$OraInstallLogDir = "$env:ProgramFiles\Oracle\Inventory\logs" 

# Installer Arguments: Uses -noconsole for true silence.
$InstallerArguments = "-silent -responseFile `"$ResponseFilePath`" -noconsole -waitforcompletion" 


# --- 2. FILE STAGING: COPY AND EXTRACT ---
Write-Host "--- 1/2: Staging Files ---"

# Create target directory (ensure C:\Temp is also checked if it doesn't exist)
if (-not (Test-Path $DestinationTempPath)) {
    New-Item -Path $DestinationTempPath -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path $ExtractPath)) {
    New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
    Write-Host "Created extraction path: $ExtractPath"
}

# --- A. Copy Response File ---
Write-Host "Copying Response File $ResponseFileName to $DestinationTempPath..."
try {
    # Destination is now C:\Temp\client_silent.rsp
    Copy-Item -Path $SourceRspPath -Destination $ResponseFilePath -Force -ErrorAction Stop
    Write-Host "Copied $ResponseFileName successfully to $ResponseFilePath."
}
catch {
    Write-Error "FATAL ERROR: Failed to copy Response File. Check permissions to access UNC path."
    Write-Error "Error Details: $($_.Exception.Message)"
    exit 1
}

# --- B. Copy Zip File ---
Write-Host "Copying $ZipFileName from $SourceZipPath..."
try {
    Copy-Item -Path $SourceZipPath -Destination $LocalZipPath -Force -ErrorAction Stop
    Write-Host "Copied $ZipFileName successfully."
}
catch {
    Write-Error "FATAL ERROR: Failed to copy zip file from Azure File Share. Check UNC path/access."
    Write-Error "Error Details: $($_.Exception.Message)"
    exit 1
}

# --- C. Extract Zip File ---
Write-Host "Extracting files..."
try {
    Expand-Archive -Path $LocalZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop
    Write-Host "Extracted files successfully."
}
catch {
    Write-Error "FATAL ERROR: Failed to extract the zip file."
    Write-Error "Error Details: $($_.Exception.Message)"
    exit 1
}

# Clean up the zip file
Remove-Item $LocalZipPath -Force | Out-Null
Write-Host "Cleaned up local zip file."


# --- 3. ORACLE CLIENT INSTALLATION ---
Write-Host "`n--- 2/2: Starting Installation ---"

# Validation checks
if (-not (Test-Path $SetupExePath)) {
    Write-Error "FATAL ERROR: Cannot find setup.exe after extraction."
    exit 1
}

Write-Host "Starting installation process for $SetupExePath..."
Write-Host "Arguments: $InstallerArguments"

# Execute setup.exe and wait for completion
$ProcessResult = Start-Process -FilePath $SetupExePath `
                                -ArgumentList $InstallerArguments `
                                -PassThru `
                                -Wait

# --- 4. STATUS CHECK ---

$ExitCode = $ProcessResult.ExitCode

Write-Host "Installation completed. Exit Code: $ExitCode"

if ($ExitCode -eq 0) {
    Write-Host "SUCCESS: Oracle Client installation finished (Exit Code 0)."
    Write-Host "Review logs in $OraInstallLogDir."
}
else {
    Write-Error "FAILURE: Installation failed with Exit Code: $ExitCode."
    Write-Error "Check the logs in $OraInstallLogDir for details."
}

# Exit with the installer's status code
exit $ExitCode
