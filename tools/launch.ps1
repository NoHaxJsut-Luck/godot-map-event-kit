param([switch]$Editor, [string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $localEngine = Join-Path (Split-Path -Parent $projectRoot) '.tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $GodotPath = $localEngine }
    elseif ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) { $GodotPath = $env:GODOT_BIN }
    else {
        $candidate = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { $GodotPath = $candidate.Source }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    Write-Host 'Godot was not found. Import project.godot in Godot 4.7.2, or set GODOT_BIN to your executable.'
    Read-Host 'Press Enter to close'
    exit 1
}
$launchArgs = @('--path', ('"' + $projectRoot + '"'))
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.godot\global_script_class_cache.cfg'))) {
    Start-Process -FilePath $GodotPath -ArgumentList (@('--headless', '--editor', '--import', '--quit') + $launchArgs) -WindowStyle Hidden -Wait
}
if ($Editor) { $launchArgs += @('--editor', 'res://demo/courtyard.tscn') }
Start-Process -FilePath $GodotPath -ArgumentList $launchArgs
