<#
.SYNOPSIS
  One-command installer for netcore-ai-rules - copy .ai-rules + skills + entry docs into a target .NET project.

.USAGE
  # From this repo (local):
  ./install.ps1 -Target ../MyProject
  ./install.ps1 -Target ../CRM -Company CRM -ProjectName CRM -Database crm -Schema app -Force
  ./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Force

  # One-liner from GitHub (no clone) - installs into the current directory:
  irm https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.ps1 | iex

  # See .ai-rules/TEMPLATE_VARS.md for what each placeholder means + more examples.
  # Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI,
  # so a non-ASCII character inside a string breaks parsing.

.PARAMETER Target   Target repo root (default: current directory)
.PARAMETER Company  Replace {Company} placeholder
.PARAMETER ProjectName Replace {ProjectName}
.PARAMETER Database Replace {database}
.PARAMETER Schema   Replace {schema}
.PARAMETER Namespace Replace {namespace}
.PARAMETER Force    Overwrite existing files
.PARAMETER DryRun   Print what would be done
#>
param(
  [string]$Target = ".",
  [string]$Company = "",
  [string]$ProjectName = "",
  [string]$Database = "",
  [string]$Schema = "",
  [string]$Namespace = "",
  [switch]$Force,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Resolve source = folder where this script lives (repo root of netcore-ai-rules)
$Source = $PSScriptRoot
if (-not $Source -or $Source -eq "") { $Source = (Get-Location).Path }
# When invoked via irm|iex, $PSScriptRoot is empty - fetch from temp clone
if (-not (Test-Path (Join-Path $Source ".ai-rules"))) {
  Write-Host "[netcore-ai-rules] .ai-rules not found next to script, attempting remote fetch..." -ForegroundColor Yellow
  $tmp = Join-Path $env:TEMP ("netcore-ai-rules-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
  git clone --depth 1 https://github.com/thanhsonvnhp/netcore-ai-rules.git $tmp 2>$null
  if (Test-Path (Join-Path $tmp ".ai-rules")) { $Source = $tmp } else { throw "Cannot locate source .ai-rules. Clone https://github.com/thanhsonvnhp/netcore-ai-rules.git first." }
}

try { $resolved = Resolve-Path $Target -ErrorAction Stop; $Target = $resolved.Path } catch {
  if ([System.IO.Path]::IsPathRooted($Target)) { $t = $Target } else { $t = Join-Path (Get-Location).Path $Target }
  if (-not (Test-Path $t)) { New-Item -ItemType Directory -Force $t | Out-Null }
  $Target = (Resolve-Path $t).Path
}

Write-Host "[netcore-ai-rules] Source : $Source" -ForegroundColor Cyan
Write-Host "[netcore-ai-rules] Target : $Target" -ForegroundColor Cyan

$vars = @{}
if ($Company)     { $vars["{Company}"] = $Company }
if ($ProjectName) { $vars["{ProjectName}"] = $ProjectName }
if ($Database)    { $vars["{database}"] = $Database }
if ($Schema)      { $vars["{schema}"] = $Schema }
if ($Namespace)   { $vars["{namespace}"] = $Namespace }

# Replace global {Placeholder} values in one installed file. <placeholder> forms are never touched.
# TEMPLATE_VARS.md is skipped: it documents the placeholder names, replacing them would destroy its own table.
# Explicit UTF-8 (no BOM) I/O: Get-Content/Set-Content default to ANSI on Windows PowerShell 5.1.
function Update-Placeholders($path) {
  if ($vars.Count -eq 0 -or (Split-Path $path -Leaf) -eq "TEMPLATE_VARS.md") { return $false }
  $c = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $orig = $c
  foreach ($k in $vars.Keys) { $c = $c.Replace($k, $vars[$k]) }
  if ($c -eq $orig) { return $false }
  [System.IO.File]::WriteAllText($path, $c, (New-Object System.Text.UTF8Encoding $false))
  return $true
}

function Copy-Tree($srcRel, $dstRel) {
  $src = Join-Path $Source $srcRel
  $dst = Join-Path $Target $dstRel
  if (-not (Test-Path $Src)) { Write-Host "  skip $srcRel (not in source)" -ForegroundColor DarkGray; return }
  $files = Get-ChildItem $src -Recurse -File
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($src.Length).TrimStart('\','/')
    $destFile = Join-Path $dst $rel
    $destDir = Split-Path $destFile -Parent
    if ($DryRun) { Write-Host "  [dry-run] $dstRel/$rel" -ForegroundColor DarkGray; continue }
    if ((Test-Path $destFile) -and -not $Force) { Write-Host "  skip $dstRel/$rel (exists, use -Force)" -ForegroundColor Yellow; continue }
    New-Item -ItemType Directory -Force $destDir | Out-Null
    Copy-Item $f.FullName $destFile -Force
    Write-Host "  + $dstRel/$rel" -ForegroundColor Green
    if (Update-Placeholders $destFile) { Write-Host "    -> replaced placeholders in $rel" -ForegroundColor DarkCyan }
  }
}

function Copy-Single($srcRel, $dstRel) {
  $src = Join-Path $Source $srcRel
  $dst = Join-Path $Target $dstRel
  if (-not (Test-Path $src)) { return }
  if ((Test-Path $dst) -and -not $Force) { Write-Host "  skip $dstRel (exists, use -Force)" -ForegroundColor Yellow; return }
  if ($DryRun) { Write-Host "  [dry-run] $dstRel" -ForegroundColor DarkGray; return }
  New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
  Copy-Item $src $dst -Force
  Write-Host "  + $dstRel" -ForegroundColor Green
  [void](Update-Placeholders $dst)
}

Write-Host "`n[1/3] .ai-rules/ ..." -ForegroundColor White
Copy-Tree ".ai-rules" ".ai-rules"

Write-Host "[2/3] skills ..." -ForegroundColor White
# Source skills live in .agents/skills - install to .agents/skills (generic)
# and .claude/skills (Claude Code discovers skills here)
Copy-Tree ".agents/skills" ".agents/skills"
Copy-Tree ".agents/skills" ".claude/skills"

Write-Host "[3/3] entry docs ..." -ForegroundColor White
Copy-Single "CLAUDE.md" "CLAUDE.md"
Copy-Single "AGENTS.md" "AGENTS.md"
# Personal plan folder - its .gitignore keeps every plan file out of git
Copy-Single ".plans/.gitignore" ".plans/.gitignore"

if (-not $DryRun) {
  # Friendly next steps
  $hasPlaceholders = Select-String -Path (Join-Path $Target ".ai-rules/core/01-project-hard-rules.md") -Pattern "\{ProjectName\}|\{Company\}|\{database\}" -Quiet -ErrorAction SilentlyContinue
  Write-Host "`n[netcore-ai-rules] Done." -ForegroundColor Green
  if ($hasPlaceholders -and $vars.Count -eq 0) {
    Write-Host "  Next: replace placeholders - re-run the installer with values and -Force:" -ForegroundColor Yellow
    Write-Host "  Example: ./install.ps1 -Target <project> -Company Acme -ProjectName MyApp -Database myapp -Schema app -Force" -ForegroundColor DarkGray
  }
  Write-Host "  Docs: .ai-rules/README.md  |  Vars: .ai-rules/TEMPLATE_VARS.md" -ForegroundColor DarkGray
} else {
  Write-Host "`n[dry-run] No files written. Remove -DryRun to apply." -ForegroundColor Yellow
}
