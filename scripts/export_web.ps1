param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$buildPath = Join-Path $projectPath 'build\web'
$publishPath = Join-Path $projectPath 'docs'
New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $projectPath 'build\.gdignore') -Force | Out-Null

# Wait explicitly: some Windows GUI Godot executables otherwise return early.
$arguments = @('--headless', '--path', ('"' + $projectPath + '"'), '--export-release', 'Web', ('"' + (Join-Path $buildPath 'index.html') + '"'))
$exportProcess = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($exportProcess.ExitCode -ne 0) { throw "Godot export failed ($($exportProcess.ExitCode))." }
foreach ($requiredFile in @('index.html', 'index.js', 'index.pck', 'index.wasm')) {
    if (!(Test-Path -LiteralPath (Join-Path $buildPath $requiredFile))) { throw "Missing export: $requiredFile" }
}
$exportFiles = Get-ChildItem -LiteralPath $buildPath -File | Where-Object { $_.Name -like 'index.*' -and $_.Extension -ne '.import' }
$exportFiles | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $publishPath -Force
}
New-Item -ItemType File -Path (Join-Path $publishPath '.nojekyll') -Force | Out-Null
Compress-Archive -LiteralPath $exportFiles.FullName -DestinationPath (Join-Path $projectPath 'build\SoftMountain-Web.zip') -Force
Write-Host 'Browser build ready in docs/. Commit those files and push main to update GitHub Pages.'
