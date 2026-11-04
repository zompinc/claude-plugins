# wt-resume

Resumes Claude Code sessions after Windows Terminal or Windows restarts. Each pane that was running Claude when Terminal closed comes back running `claude --resume` on the same session, in the same directory, while the other panes start as plain shells.

Windows only, PowerShell 7 or Windows PowerShell.

## Install

```sh
claude plugin marketplace add zompinc/claude-plugins
claude plugin install wt-resume@zomp-tools
```

Then add this line to your PowerShell profile (`$PROFILE`):

```powershell
if (Test-Path ~/.claude/wt-resume/resume-pane.ps1) { . ~/.claude/wt-resume/resume-pane.ps1 }
```

In Windows Terminal, set `"firstWindowPreference": "persistedLayout"` so it restores your tabs and panes.

Sessions already running are only recorded once they restart. To record them right away, run the snapshot once (the path is printed by `claude plugin list`):

```powershell
& <plugin directory>/scripts/wt-pane-session.ps1 -Snapshot
```

## How it works

Every Windows Terminal pane has an id in `WT_SESSION`. With a persisted layout, Terminal saves it and gives the restored pane the same id, so it identifies the pane across a restart.

- `SessionEnd` records `{sessionId, cwd}` in `~/.claude/wt-resume/<WT_SESSION>.json` when the session ends because the pane, the window or Windows is closing. Ending it with `/exit`, Ctrl+D or `/clear` deletes the record instead. Records older than 14 days are deleted.
- The profile line runs `resume-pane.ps1` in every new shell. If a record exists for the shell's pane, it deletes it, changes to the recorded directory and runs `claude --resume`. Shells started by Claude (`CLAUDECODE`) and shells nested under a resumed one are skipped.
- `SessionStart` copies `resume-pane.ps1` to `~/.claude/wt-resume/`, so the profile line keeps working across plugin updates.

Each record is used once; the next close records whatever is running then.

`-Snapshot` reads `~/.claude/sessions/<pid>.json`, Claude Code's map of running processes to sessions, and takes each process's `WT_SESSION` from its environment block.

## Notes

- Mount any drive the sessions live on before starting Terminal; otherwise `--resume` cannot find them.
- If Windows ends Terminal before its panes close, `SessionEnd` never runs and nothing is recorded. Run `-Snapshot` before a planned restart to be safe.
- Many panes resuming at once start many Claude processes at once.
