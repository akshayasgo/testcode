<#
.SYNOPSIS
    Stage 1: Copies files, installs .NET Framework 4.8, and forces a system reboot if necessary.
.DESCRIPTION
    1. Authenticates and copies installers from the Azure File Share to C:\Temp, with retry logic.
    2. Checks for and installs .NET Framework 4.8.
    3. IF A REBOOT IS REQUIRED, IT EXECUTES RESTART-COMPUTER and exits successfully.
#>

# --- Global Configuration ---
$logFile = "C:\Temp\InstallationLog.log"
$tempDir = "C:\Temp"
$exitCodeSuccess = 0
$exitCodeFailure = 1
$rebootNeeded = $false # Global flag

# --- Azure Storage Authentication Configuration ---
$storageAccountName = "teastasjay"
$storageAccountKey = ""
$fileShareUNC = "\\teastasjay.file.core.windows.net\test\oracle"


# --- File Share Copy Configuration ---
$sourceSharePath = $fileShareUNC 

$filesToCopy = @(
    @{ Source = "NDP48-x86-x64-AllOS-ENU.exe"; Destination = Join-Path $tempDir "NDP48-x86-x64-AllOS-ENU.exe" },
    @{ Source = "Octopus.Tentacle.8.3.3164-x64.msi"; Destination = Join-Path $tempDir "Octopus.Tentacle.8.3.3164-x64.msi" }
)

# --- Installation Artifacts Configuration ---
$dotNetInstallPath = Join-Path $tempDir "NDP48-x86-x64-AllOS-ENU.exe"
$dotNetSilentArgs = "/q /norestart"
$dotNetTargetRelease = 528040

$maxRetries = 5 
$retryDelaySec = 2

# --- Helper Functions (Stage 1) ---

function Write-Log {
    param([string]$Message)
    # FIX: Explicitly use $script:logFile to ensure scope is maintained in CSE
    "$(Get-Date -Format 'HH:mm:ss') - $Message" | Out-File $script:logFile -Append
}

function Check-DotNet48Installed {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
    if (Test-Path $registryPath) {
        $releaseValue = (Get-ItemProperty -Path $registryPath -Name Release -ErrorAction SilentlyContinue).Release
        # FIX: Explicitly use $script:dotNetTargetRelease
        if ($releaseValue -ne $null -and $releaseValue -ge $script:dotNetTargetRelease) {
            return $true
        }
    }
    return $false
}

function Copy-AllFilesFromShare {
    # FIX: Explicitly use $script:sourceSharePath
    Write-Log "STEP 0: Authenticating and copying files from UNC path: $script:sourceSharePath"
    
    $mappedDrive = "Z:"
    
    try {
        Write-Log "Attempting net use authentication with credentials..."
        # FIX: Explicitly use $script:storageAccountName and $script:storageAccountKey
        net use $mappedDrive $script:sourceSharePath /user:$script:storageAccountName $script:storageAccountKey /persistent:no
        
        if (-not (Test-Path $script:sourceSharePath)) {
            throw "Authentication successful, but UNC path is still not accessible. Check network firewall rules."
        }
        
        # FIX: Explicitly use $script:filesToCopy
        foreach ($file in $script:filesToCopy) {
            $sourceFile = Join-Path $script:sourceSharePath $file.Source 
            $destinationFile = $file.Destination
            
            if (Test-Path $destinationFile) {
                Write-Log "File '$($file.Source)' already exists locally. Skipping copy."
                continue
            }

            Write-Log "Copying '$($file.Source)' from '$script:sourceSharePath' to '$destinationFile'"
            Copy-Item -Path $sourceFile -Destination $destinationFile -Force
            
            if (-not (Test-Path $destinationFile)) {
                 throw "Copy-Item failed to copy file: $($file.Source)."
            }
        }
        Write-Log "All files copied successfully."
        return $true
    }
    catch {
        throw $_
    }
    finally {
        Write-Log "Cleaning up authenticated connection."
        net use $mappedDrive /delete /y
    }
}

function Install-DotNet48 {
    Write-Log "STEP 1: Checking/Installing .NET Framework 4.8"
    if (Check-DotNet48Installed) {
        Write-Log ".NET Framework 4.8 already installed. Skipping."
        return $true
    }

    Write-Log "Installing .NET Framework 4.8 silently..."
    # FIX: Explicitly use $script:dotNetInstallPath and $script:dotNetSilentArgs
    $process = Start-Process -FilePath $script:dotNetInstallPath -ArgumentList $script:dotNetSilentArgs -Wait -PassThru -NoNewWindow
    $exitCode = $process.ExitCode
    
    if ($exitCode -eq 0) {
        Write-Log "Installation succeeded (Exit Code: $exitCode)."
        return $true
    } elseif ($exitCode -eq 3010) {
        $script:rebootNeeded = $true
        Write-Log "Installation succeeded (Exit Code: $exitCode). A mandatory reboot is required."
        return $true
    } else {
        throw "DOTNET_ERROR: Installation failed with installer Exit Code: $exitCode."
    }
}

# --- STAGE 1 WORKFLOW (Run this script first) ---
try {
    # 0. File Copy with Retry Logic
    $copySuccess = $false
    # FIX: Explicitly use $script:maxRetries
    for ($i = 0; $i -lt $script:maxRetries; $i++) {
        try {
            Write-Log "Attempt $($i + 1)/$script:maxRetries: Attempting file copy."
            Copy-AllFilesFromShare
            $copySuccess = $true
            break
        }
        catch {
            if ($_.Exception.Message -like "*FATAL FILE COPY ERROR:*" -or $_.Exception.Message -like "*Authentication successful, but UNC path is still not accessible*") {
                # FIX: Explicitly use $script:retryDelaySec
                Write-Log "WARNING: File copy attempt $($i + 1) failed due to network access issues. Retrying in $script:retryDelaySec seconds..."
                if ($i -lt $script:maxRetries - 1) { Start-Sleep -Seconds $script:retryDelaySec } else {
                    throw "FILE_COPY_ERROR: All retry attempts failed to copy files from share. Last error: $($_.Exception.Message)"
                }
            } else { throw $_ }
        }
    }
    
    # 1. .NET Installation
    Install-DotNet48
    
    # --- MANDATORY REBOOT CHECK ---
    if ($rebootNeeded -eq $true) {
        Write-Log "MANDATORY REBOOT INITIATED: VM will restart. Rerun the Stage 2 script after the reboot."
        Restart-Computer -Force
        exit $script:exitCodeSuccess 
    }
    
    Write-Log "SUCCESS: Stage 1 completed. No reboot required or reboot already handled."
    exit $script:exitCodeSuccess
}
catch {
    Write-Log "FATAL SCRIPT FAILURE (STAGE 1): $($_.Exception.Message)"
    Write-Error "Script failed: $($_.Exception.Message)"
    exit $script:exitCodeFailure
}
