# Stage 2: Install Octopus Tentacle Agent Only (No Checks or Config)

$tentacleInstaller = "C:\Temp\Octopus.Tentacle.8.3.3164-x64.msi"
$installDir = "D:\Octopus\Tentacle"
$logFile = "C:\Temp\InstallationLog.log"

function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') - $msg" | Out-File $logFile -Append }

try {
    New-Item -Path "C:\Temp","$installDir" -ItemType Directory -Force | Out-Null
    Log "--- Starting Tentacle Agent Installation ---"

    if (-not (Test-Path $tentacleInstaller)) { throw "Installer not found at $tentacleInstaller" }

    $args = "/i `"$tentacleInstaller`" /qn /norestart ALLUSERS=1 INSTALLDIR=`"$installDir`""
    Log "Running MSI installer..."
    $process = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0) { 
        Log "Tentacle Agent installation completed successfully."
        exit 0
    } else {
        throw "MSI failed with Exit Code $($process.ExitCode)"
    }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Write-Error $_.Exception.Message
    exit 1
}
