$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$project = Join-Path $root 'project'
$runtime = Join-Path $root 'Godot_v4.7.1-stable_win64.exe'
$launcher = Join-Path $root 'Start_Terminus_Battles.bat'
$zipPath = Join-Path $root 'Terminus-Battles-Playtest.zip'
$tempPath = Join-Path $root 'Terminus-Battles-Playtest.new.zip'
if (-not (Test-Path -LiteralPath $runtime)) { throw "Godot runtime not found: $runtime" }
if (-not (Test-Path -LiteralPath $launcher)) { throw "Game launcher not found: $launcher" }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
$files = @((Get-Item -LiteralPath $runtime), (Get-Item -LiteralPath $launcher))
$files += Get-ChildItem -LiteralPath $project -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' }
$importedCache = Join-Path $project '.godot\imported'
if (Test-Path -LiteralPath $importedCache) { $files += Get-ChildItem -LiteralPath $importedCache -File -Recurse }
$archive = [System.IO.Compression.ZipFile]::Open($tempPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($root.Length).TrimStart([char[]](92, 47)).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, "Terminus-Battles-Playtest/$relative", [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally { $archive.Dispose() }
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Move-Item -LiteralPath $tempPath -Destination $zipPath
$item = Get-Item -LiteralPath $zipPath
Write-Output "Created $($item.FullName) ($([math]::Round($item.Length / 1MB, 1)) MB)"
