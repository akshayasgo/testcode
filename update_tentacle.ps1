$tentacleInstaller = "C:\Temp\Octopus.Tentacle.8.3.3164-x64.msi"
$installDir = "D:\Octopus Deploy\Tentacle"
$logFile = "C:\Temp\TentacleInstallation.log"

function Log($msg) {
    "$(Get-Date -Format 'HH:mm:ss') - $msg" | Out-File $logFile -Append
}

try {
    Log "--- Starting Octopus Tentacle Installation ---"

    # Ensure installer exists
    if (-not (Test-Path $tentacleInstaller)) {
        throw "Installer not found at path: $tentacleInstaller"
    }

    # Ensure installation directory exists
    if (-not (Test-Path $installDir)) {
        Log "Creating install directory at $installDir"
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
    }

    # ✅ INSTALLLOCATION is the correct property for Octopus Tentacle
    $arg = "/i `"$tentacleInstaller`" /qn /norestart ALLUSERS=1 INSTALLLOCATION=`"$installDir`""

    Log "Running MSI installer with args: $arg"

    $process = Start-Process msiexec.exe -ArgumentList $arg -Wait -Passthru -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Log "Octopus Tentacle installed successfully in $installDir"
        Write-Host "✅ Installation completed successfully in $installDir"
        exit 0
    } else {
        throw "MSI installation failed with exit code $($process.ExitCode)"
    }
}
catch {
    Log "❌ ERROR: $($_.Exception.Message)"
    Write-Error $_.Exception.Message
    exit 1
}
