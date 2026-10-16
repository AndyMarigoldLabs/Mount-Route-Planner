param(
    [Parameter(Mandatory = $true)][string]$BaseZip,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
$baseArchive = (Resolve-Path -LiteralPath $BaseZip).Path
# This overlay is based on upstream v2.4.5; reject unrelated archives.
$expectedHash = '6e014073cfa640715e8482f226e074acc2f417af075a7e7b1f75fc1b10bbecbb'
if ((Get-FileHash -LiteralPath $baseArchive -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Expected the upstream v2.4.5 MountRoutePlanner_Bundled.zip (SHA256 mismatch).'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
$staging = Join-Path $outputRoot ('staging-' + [guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $baseArchive -DestinationPath $staging
$addonRoot = Join-Path $staging 'MountRoutePlanner'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Public sources retain development markers. Match the release namespace and
# omit development-only lines without depending on upstream's private tooling.
$runtimeFiles = @(
    'MRP_CharacterSettings.lua', 'MRP_Core.lua', 'MRP_Filter.lua', 'MRP_Map.lua',
    'MRP_Options.lua', 'MRP_Route.lua', 'MRP_UI.lua', 'MRP_Util.lua',
    'MRP_Prerequisites.lua', 'MRP_Unlocks.lua', 'MRP_Dailies.lua', 'MRP_UnlockRouting.lua',
    'Data\MRP_UnlockDailies.lua',
    'Data\MRP_PrerequisiteData.lua', 'Data\MRP_UnlockNetherwing.lua', 'Data\MRP_UnlockTournament.lua', 'Locale\MRP_Locale.enUS.lua'
)
foreach ($relative in $runtimeFiles) {
    $source = Join-Path $repoRoot $relative
    $destination = Join-Path $addonRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    $lines = Get-Content -LiteralPath $source -Encoding UTF8
    $lines = $lines | Where-Object { $_ -notmatch '-- REMOVE_LINE' } | ForEach-Object {
        $_ -replace '^-- local _, MRP = \.\.\.$', 'local _, MRP = ...'
    }
    [IO.File]::WriteAllText($destination, ($lines -join "`n") + "`n", $utf8)
}
$tocPath = Join-Path $addonRoot 'MountRoutePlanner.toc'
$toc = [IO.File]::ReadAllText($tocPath)
$toc = $toc.Replace('MRP_Util.lua', "MRP_Util.lua`nMRP_Prerequisites.lua`nMRP_Unlocks.lua`nMRP_Dailies.lua`nData\MRP_PrerequisiteData.lua`nData\MRP_UnlockNetherwing.lua`nData\MRP_UnlockTournament.lua`nData\MRP_UnlockDailies.lua`nMRP_UnlockRouting.lua")
$toc = $toc.Replace('## Version: v2.4.5', '## Version: v2.4.5-quest-dev')
[IO.File]::WriteAllText($tocPath, $toc, $utf8)
$archive = Join-Path $outputRoot 'MountRoutePlanner-quest-dev.zip'
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive -Force
Write-Output "Local test build: $archive"
Write-Output "Expanded build: $staging"
