param(
    [switch]$TagOnSuccess,
    [string]$GitMessage = "Bump build number and build APK"
)

# Usage: ./scripts/build_and_bump.ps1 [-TagOnSuccess]

$pubspec = "pubspec.yaml"
if (-not (Test-Path $pubspec)) {
    Write-Error "pubspec.yaml not found in current directory"
    exit 1
}

$content = Get-Content $pubspec -Raw
$versionLine = ($content -split "\n" | Where-Object { $_ -match '^version:' })[0]
if (-not $versionLine) {
    Write-Error "No version line found in pubspec.yaml"
    exit 1
}

# version: 1.2.3+45
if ($versionLine -match 'version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
    $build = [int]$matches[4]
    $newBuild = $build + 1
    $newVersion = "version: $major.$minor.$patch+$newBuild"
    Write-Host "Bumping build from $build -> $newBuild"
    $newContent = $content -replace [regex]::Escape($versionLine), $newVersion
    Set-Content -Path $pubspec -Value $newContent -Encoding UTF8
} else {
    Write-Error "Version format not recognized. Expected 'x.y.z+build'"
    exit 1
}

# Run flutter build apk
Write-Host "Running: flutter build apk"
$proc = Start-Process -FilePath flutter -ArgumentList 'build','apk' -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Error "flutter build apk failed with exit code $($proc.ExitCode)"
    exit $proc.ExitCode
}

Write-Host "flutter build apk succeeded"

# Optionally commit and tag
if ($TagOnSuccess) {
    git add pubspec.yaml
    git commit -m "$GitMessage"
    $tag = "v$major.$minor.$patch+$newBuild"
    git tag -a $tag -m "Build $newBuild"
    Write-Host "Created git tag: $tag"
}

Write-Host "Done. New version: $major.$minor.$patch+$newBuild"
