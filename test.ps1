# --- 1. Configuration: ADJUST THESE VARIABLES ---

# The full path to the setup.exe in your extracted Oracle Client files
$SetupExePath = "C:\Oracle19cInstall\Extracted\client\setup.exe" 

# The full path to your customized response file
$ResponseFilePath = "C:\Users\akshay9826\Downloads\client_silent.rsp" 

# Directory to find the installer logs
$OraInstallLogDir = "$env:ProgramFiles\Oracle\Inventory\logs" 

# UPDATED ARGUMENTS: Added -noconsole to suppress the final "Press Enter to exit" prompt.
# -silent -responseFile <path> -noconsole -waitforcompletion
$InstallerArguments = "-silent -responseFile `"$ResponseFilePath`" -noconsole -waitforcompletion" 

# --- 2. Validation and Execution ---
Write-Host "--- Oracle Client Silent Installation ---"

# Check if setup.exe exists
if (-not (Test-Path $SetupExePath)) {
    Write-Error "ERROR: Cannot find setup.exe at '$SetupExePath'. Please check the path and extraction."
    exit 1
}

# Check if response file exists
if (-not (Test-Path $ResponseFilePath)) {
    Write-Error "ERROR: Cannot find response file at '$ResponseFilePath'. Please check the path."
    exit 1
}

Write-Host "Starting installation process for $SetupExePath..."
Write-Host "Arguments: $InstallerArguments"

# Execute setup.exe, wait for it to complete, and capture the process object
# Ensure this script is run with Administrator privileges!
$ProcessResult = Start-Process -FilePath $SetupExePath `
                                -ArgumentList $InstallerArguments `
                                -PassThru `
                                -Wait

# --- 3. Status Check and Logging ---

$ExitCode = $ProcessResult.ExitCode

Write-Host "Installation completed. Checking exit code..."
Write-Host "Installer Exit Code: $ExitCode"

if ($ExitCode -eq 0) {
    Write-Host "SUCCESS: Oracle Client installation finished successfully (Exit Code 0)."
    Write-Host "Review the log files in $OraInstallLogDir for final confirmation."
}
else {
    Write-Error "FAILURE: Oracle Client installation failed or finished with a non-zero exit code ($ExitCode)."
    Write-Error "Please check the log files in $OraInstallLogDir for details on the error."
}

# Always exit the script with the installer's exit code for remote monitoring tools
exit $ExitCode
