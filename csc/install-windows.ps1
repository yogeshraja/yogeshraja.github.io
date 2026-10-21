<#
.SYNOPSIS
    install-windows.ps1 — one-command setup for a fresh Windows machine.

.DESCRIPTION
    Clones the (private) custom-shell-config repo and runs install.ps1. The
    PowerShell counterpart of install-unix.sh. Meant to be hosted publicly and
    run from a fresh PowerShell (usually reached via the cross-OS entry point,
    irm .../csc/setup | iex):

        irm https://yogeshraja.github.io/csc/install-windows.ps1 | iex

    For a lean install, fetch then invoke with the switch (piping to iex can't
    pass args):

        & ([scriptblock]::Create((irm https://yogeshraja.github.io/csc/install-windows.ps1))) -Lean

    This script is PUBLIC — it holds no secrets. Access to the private repo
    comes from git's own HTTPS prompt (username + a Personal Access Token),
    never from anything baked in here.

    Overridable via env: REPO_OWNER, REPO_NAME, DEST.

.PARAMETER Lean
    Forwarded to install.ps1: fast install (essential tools + prompt wiring).
#>
[CmdletBinding()]
# $Lean IS used — in Main() (forwarded to install.ps1). PSSA's
# PSReviewUnusedParameter doesn't see usage across the nested function scope, so
# this is a false positive; suppress with justification (mirrors install.ps1).
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Lean',
    Justification = 'Used inside Main(); PSSA misses cross-function-scope usage')]
param(
    [switch]$Lean
)

$ErrorActionPreference = "Stop"

# --- Config (env-overridable, mirroring install-unix.sh) ---
$RepoOwner = if ($env:REPO_OWNER) { $env:REPO_OWNER } else { "yogeshraja" }
$RepoName  = if ($env:REPO_NAME)  { $env:REPO_NAME }  else { ".custom_shell_config" }
$Dest      = if ($env:DEST)       { $env:DEST }       else { Join-Path $HOME ".custom_shell_config" }
$HttpsUrl  = "https://github.com/$RepoOwner/$RepoName.git"
# SSH remote to hand off to once keys are restored. Uses the "$RepoOwner" host,
# which matches a personal SSH-config alias (keeps a personal key separate from
# a work github.com host); override SSH_URL if yours differs.
$SshUrl    = if ($env:SSH_URL) { $env:SSH_URL } else { "git@${RepoOwner}:$RepoOwner/$RepoName.git" }

function Say  { param([string]$m) Write-Host "> $m" -ForegroundColor Blue }
function Warn { param([string]$m) Write-Host "! $m" -ForegroundColor Yellow }
function Die  { param([string]$m) Write-Host "x $m" -ForegroundColor Red; exit 1 }

function Test-Cmd { param([string]$n) $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

# Ensure git is available, installing it where we safely can (winget, then
# scoop, then choco). If none is present, stop with a clear message rather than
# guessing.
function Install-GitIfMissing {
    if (Test-Cmd "git") { return }
    Say "git not found — attempting to install it..."
    if (Test-Cmd "winget") {
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    }
    elseif (Test-Cmd "scoop") {
        scoop install git
    }
    elseif (Test-Cmd "choco") {
        choco install git -y
    }
    else {
        Die "Could not auto-install git (no winget/scoop/choco). Install Git for Windows, open a new shell, then re-run."
    }
    # winget/choco update PATH for *new* shells; make git usable in this one.
    if (-not (Test-Cmd "git")) {
        $gitCandidates = @(
            "$env:ProgramFiles\Git\cmd",
            "${env:ProgramFiles(x86)}\Git\cmd",
            "$env:LOCALAPPDATA\Programs\Git\cmd"
        )
        foreach ($c in $gitCandidates) {
            if (Test-Path (Join-Path $c "git.exe")) { $env:PATH = "$c;$env:PATH"; break }
        }
    }
    if (-not (Test-Cmd "git")) {
        Die "git installed but not on PATH in this session. Open a new PowerShell and re-run."
    }
}

# Clone over HTTPS — git prompts for username + a Personal Access Token
# (a fresh machine has no SSH key yet).
function Invoke-Clone {
    Say "Cloning over HTTPS — git will prompt for your username and a Personal Access Token..."
    git clone --recursive $HttpsUrl $Dest
    if ($LASTEXITCODE -ne 0) { Die "Clone failed." }
}

# After install.ps1 restores the personal SSH key, point origin at SSH so the
# key is used. Only rewrites an HTTPS origin; an already-SSH origin is left as-is.
function Switch-RemoteToSsh {
    $cur = (git -C $Dest remote get-url origin 2>$null)
    if (-not $cur) { Warn "No 'origin' remote to switch."; return }
    if ($cur -notlike "https://*") { return }   # already SSH (or other) — leave it

    # Need a personal key for the SSH remote to authenticate. Match the secret
    # key file itself (the *_personal pattern), not a .pub.
    $keys = Get-ChildItem -Path (Join-Path $HOME ".ssh") -Filter "*_personal" -File -ErrorAction SilentlyContinue
    if (-not $keys) {
        Warn "No personal SSH key (~/.ssh/*_personal) yet — leaving origin on HTTPS. Switch later with:"
        Write-Host "     git -C `"$Dest`" remote set-url origin $SshUrl"
        return
    }

    git -C $Dest remote set-url origin $SshUrl
    if ($LASTEXITCODE -eq 0) {
        Say "Switched origin to SSH: $SshUrl"
    }
    else {
        Warn "Couldn't switch origin. Do it manually:"
        Write-Host "     git -C `"$Dest`" remote set-url origin $SshUrl"
    }
}

function Main {
    Install-GitIfMissing

    if (Test-Path (Join-Path $Dest ".git")) {
        Say "Repo already present at $Dest — updating..."
        git -C $Dest pull --recurse-submodules --ff-only
        if ($LASTEXITCODE -ne 0) { Warn "Pull failed; using the existing checkout." }
    }
    else {
        $parent = Split-Path $Dest -Parent
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Invoke-Clone
    }

    $installer = Join-Path $Dest "install.ps1"
    if (-not (Test-Path $installer)) { Die "install.ps1 not found in $Dest." }

    Say "Running install..."
    if ($Lean) {
        & pwsh -File $installer -Lean
    }
    else {
        & pwsh -File $installer
    }

    # Keys are restored by now — move origin off the HTTPS clone URL onto SSH.
    Switch-RemoteToSsh

    Say "Done. Open a new PowerShell session to load your profile."
}

Main
