# Dot-sourced from the PowerShell profile. Resumes the Claude session this
# Windows Terminal pane was running when Terminal last closed, as recorded by
# wt-pane-session.ps1. Skipped in shells that Claude itself starts and in
# shells nested under a resumed one.

$paneFile = "$env:USERPROFILE\.claude\wt-resume\$env:WT_SESSION.json"
if ($env:WT_SESSION -and -not $env:CLAUDECODE -and -not $env:CLAUDE_PANE_RESUMED -and (Test-Path $paneFile)) {
    $env:CLAUDE_PANE_RESUMED = 1
    $pane = Get-Content $paneFile -Raw | ConvertFrom-Json
    # Consumed now; the SessionEnd hook records the pane again at the next close.
    Remove-Item $paneFile
    if (Test-Path $pane.cwd) { Set-Location $pane.cwd }
    claude --resume $pane.sessionId
    Remove-Variable pane
}
Remove-Variable paneFile
