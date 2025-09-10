param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

# Prompt-based flutter run wrapper (PowerShell)
# Usage: .\scripts\flutter_run.ps1 -- <additional flutter args>

try {
    $raw = & flutter devices --machine 2>$null
} catch {
    Write-Host "Failed to run 'flutter devices'. Make sure Flutter is on PATH." -ForegroundColor Red
    exit 1
}

if (-not $raw -or $raw.Trim() -eq "") {
    Write-Host "No devices detected by 'flutter devices'." -ForegroundColor Yellow
    exit 1
}

try {
    $devices = $raw | Out-String | ConvertFrom-Json
} catch {
    Write-Host "Unable to parse JSON from 'flutter devices --machine'. Showing 'flutter devices' output instead." -ForegroundColor Yellow
    flutter devices
    exit 1
}

if ($devices.Count -eq 0) {
    Write-Host "No devices found." -ForegroundColor Yellow
    exit 1
}

Write-Host "Detected devices:`n"
for ($i = 0; $i -lt $devices.Count; $i++) {
    $d = $devices[$i]
    $name = $d.name
    $id = $d.id
    $platform = $d.platformType
    Write-Host "[$i] $name — $id ($platform)"
}

$choice = Read-Host "Select device index (press Enter to cancel)"
if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Host "Cancelled." -ForegroundColor Cyan
    exit 0
}

$parseOk = [int]::TryParse($choice, [ref]$parsed)
if (-not $parseOk) {
    Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
    exit 1
}

$index = [int]$parsed
if ($index -lt 0 -or $index -ge $devices.Count) {
    Write-Host "Selection out of range." -ForegroundColor Red
    exit 1
}

$deviceId = $devices[$index].id

Write-Host "Running 'flutter run' on device id '$deviceId'...`n"
& flutter run -d $deviceId @ExtraArgs
