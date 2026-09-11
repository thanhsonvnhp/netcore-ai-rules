<#
.SYNOPSIS
  One-command installer for netcore-ai-rules — copy .ai-rules + skills + entry docs into a target .NET project.

.USAGE
  # From this repo (local):
  ./install.ps1 -Target ../MyProject
  ./install.ps1 -Target ../CRM -Company CRM -ProjectName CRM -Database CRM -Schema app -Force
  ./install.ps1 -Target ../AcmePlatform -Company Acme -ProjectName AcmePlatform -Database acme_db -Schema catalog -Force

  # One-liner from GitHub (no clone):
  irm https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.ps1 | iex
  # then in target repo:
  .\install.ps1  # defaults to current directory
  .\install.ps1 -Company CRM -ProjectName CRM -Database CRM -Force

  # See .ai-rules/TEMPLATE_VARS.md for what each placeholder means + more examples.

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
# When invoked via irm|iex, $PSScriptRoot is empty — fetch from temp clone
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
    # placeholder replacement
    if ($vars.Count -gt 0) {
      $c = Get-Content $destFile -Raw -ErrorAction SilentlyContinue
      if ($null -ne $c) {
        $orig = $c
        foreach ($k in $vars.Keys) { $c = $c.Replace($k, $vars[$k]) }
        if ($c -ne $orig) { Set-Content $destFile $c -NoNewline; Write-Host "    -> replaced placeholders in $rel" -ForegroundColor DarkCyan }
      }
    }
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
  if ($vars.Count -gt 0) {
    $c = Get-Content $dst -Raw -ErrorAction SilentlyContinue
    if ($null -ne $c) {
      $orig = $c
      foreach ($k in $vars.Keys) { $c = $c.Replace($k, $vars[$k]) }
      if ($c -ne $orig) { Set-Content $dst $c -NoNewline }
    }
  }
}

Write-Host "`n[1/3] .ai-rules/ ..." -ForegroundColor White
Copy-Tree ".ai-rules" ".ai-rules"

Write-Host "[2/3] skills ..." -ForegroundColor White
# Source skills live in .agents/skills — install to both .agents/skills and .claude/skills for compatibility
Copy-Tree ".agents/skills" ".agents/skills"
# Also mirror to .claude/skills if target uses that convention (or if .agents not desired)
if (-not (Test-Path (Join-Path $Target ".claude/skills")) -or $Force) {
  # only mirror if .agents copy succeeded, avoid double log noise
}

Write-Host "[3/3] entry docs ..." -ForegroundColor White
Copy-Single "CLAUDE.md" "CLAUDE.md"
Copy-Single "AGENTS.md" "AGENTS.md"

# Always ensure TEMPLATE_VARS.md is available in target
Copy-Single ".ai-rules/TEMPLATE_VARS.md" ".ai-rules/TEMPLATE_VARS.md"

if (-not $DryRun) {
  # Friendly next steps
  $hasPlaceholders = Select-String -Path (Join-Path $Target ".ai-rules/core/01-project-hard-rules.md") -Pattern "\{ProjectName\}|\{Company\}|\{database\}" -Quiet -ErrorAction SilentlyContinue
  Write-Host "`n[netcore-ai-rules] Done." -ForegroundColor Green
  if ($hasPlaceholders -and $vars.Count -eq 0) {
    Write-Host "  Next: replace placeholders — either re-run with -Company/-ProjectName/-Database/-Schema" -ForegroundColor Yellow
    Write-Host "        or edit .ai-rules/TEMPLATE_VARS.md then run: ./install.ps1 -Target . -Force" -ForegroundColor Yellow
    Write-Host "  Example: ./install.ps1 -Company Acme -ProjectName MyApp -Database myapp -Schema app -Force" -ForegroundColor DarkGray
  }
  Write-Host "  Docs: .ai-rules/README.md  |  Vars: .ai-rules/TEMPLATE_VARS.md" -ForegroundColor DarkGray
} else {
  Write-Host "`n[dry-run] No files written. Remove -DryRun to apply." -ForegroundColor Yellow
}
