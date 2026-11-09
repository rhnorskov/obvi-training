# Installs the newest Obvi Training from GitHub, before it's released: downloads the repo's zip and puts it in the
# game's AddOns folder as ObviTraining. No git needed. Run it again to update. In PowerShell:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/rhnorskov/obvi-training/main/tools/install.ps1)))
#
# Options: -Path "<game folder>\_forever_\Interface\AddOns" (found by itself otherwise), -Branch main.
# An ObviTraining folder that is a link to a checkout (a developer's setup) is left as it is. Saved plans live in the
# WTF folder and are kept.
param(
    [string]$Path,
    [string]$Branch = "main"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is very slow in Windows PowerShell with the bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if (-not $Path) {
    $bases = @("${env:ProgramFiles(x86)}\World of Warcraft", "$env:ProgramFiles\World of Warcraft") +
        (Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            Join-Path $_.Root "World of Warcraft"
            Join-Path $_.Root "Games\World of Warcraft"
        })
    $found = @($bases | Select-Object -Unique | Where-Object { Test-Path $_ } |
        ForEach-Object { Get-ChildItem $_ -Directory -Filter "_*_" -ErrorAction SilentlyContinue } |
        ForEach-Object { Join-Path $_.FullName "Interface\AddOns" } | Where-Object { Test-Path $_ })
    if ($found.Count -eq 0) {
        throw "Couldn't find World of Warcraft. Run it again with -Path `"<your game folder>\_forever_\Interface\AddOns`"."
    }
    if ($found.Count -eq 1) {
        $Path = $found[0]
    } else {
        Write-Host "Which game?"
        for ($i = 0; $i -lt $found.Count; $i++) { Write-Host "  $($i + 1)) $($found[$i])" }
        $pick = [int](Read-Host "Number")
        if ($pick -lt 1 -or $pick -gt $found.Count) { throw "No such choice." }
        $Path = $found[$pick - 1]
    }
}
if (-not (Test-Path $Path)) { throw "No such folder: $Path" }

$temp = Join-Path ([IO.Path]::GetTempPath()) ("obvi-training-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory $temp | Out-Null
try {
    $zip = Join-Path $temp "obvi-training.zip"
    Write-Host "Downloading Obvi Training ($Branch) from GitHub..."
    Invoke-WebRequest -UseBasicParsing "https://github.com/rhnorskov/obvi-training/archive/refs/heads/$Branch.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $temp
    $source = Get-ChildItem $temp -Directory | Select-Object -First 1
    if (-not (Test-Path (Join-Path $source.FullName "ObviTraining.toc"))) { throw "The download has no ObviTraining.toc." }
    $target = Join-Path $Path "ObviTraining"
    $item = Get-Item $target -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
        Write-Host "ObviTraining is linked to a checkout: left as it is"
    } else {
        if ($item) { Remove-Item $target -Recurse -Force }
        New-Item -ItemType Directory $target | Out-Null
        # the addon's files, without the repo's development ones
        Get-ChildItem $source.FullName -Force | Where-Object { $_.Name -notin ".github", "tools", ".gitignore", ".pkgmeta", ".luarc.json" } |
            Copy-Item -Destination $target -Recurse
        Write-Host "Installed into $target"
    }
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Done. Restart the game (or /reload if it was already running with Obvi Training). Run this again to update."
