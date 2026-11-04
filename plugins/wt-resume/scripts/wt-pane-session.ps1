# Remembers which Claude session runs in which Windows Terminal pane, so the
# PowerShell profile can resume it when Terminal restores the pane after a
# reboot. WT_SESSION is the pane id and survives a persisted-layout restore.
#
#   wt-pane-session.ps1            hook mode: reads the hook JSON on stdin
#   wt-pane-session.ps1 -Snapshot  records every Claude already running in a Terminal pane
#
# A session that ends because its pane, the window or Windows is closing is
# recorded; one that ends by /exit, Ctrl+D or /clear is forgotten.

param([switch]$Snapshot)

$dir = Join-Path $env:USERPROFILE '.claude\wt-resume'
$null = New-Item -ItemType Directory -Force $dir

function Save-Pane($pane, $sessionId, $cwd) {
    [pscustomobject]@{ sessionId = $sessionId; cwd = $cwd } | ConvertTo-Json -Compress |
        Set-Content -LiteralPath (Join-Path $dir "$pane.json") -Encoding utf8
}

if (-not $Snapshot) {
    $e = [Console]::In.ReadToEnd() | ConvertFrom-Json
    switch ($e.hook_event_name) {
        'SessionStart' {
            # Keep the profile's copy of the resume script at a path that
            # does not change with the plugin version.
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'resume-pane.ps1') -Destination $dir -Force
        }
        'SessionEnd' {
            if (-not $env:WT_SESSION) { break }
            if ($e.reason -in 'prompt_input_exit', 'logout', 'clear') {
                Remove-Item -LiteralPath (Join-Path $dir "$($env:WT_SESSION).json") -ErrorAction SilentlyContinue
            } else {
                Save-Pane $env:WT_SESSION $e.session_id $e.cwd
            }
            # Panes that were closed for good never come back; drop their records.
            Get-ChildItem $dir -Filter *-*.json | Where-Object LastWriteTime -lt (Get-Date).AddDays(-14) | Remove-Item
        }
    }
    exit 0
}

# Snapshot: read WT_SESSION out of each running claude.exe's environment block.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ProcEnv {
    [DllImport("kernel32")] static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [DllImport("ntdll")] static extern int NtQueryInformationProcess(IntPtr h, int cls, IntPtr[] info, int len, out int ret);
    static IntPtr ReadPtr(IntPtr h, IntPtr addr) {
        var b = new byte[8]; IntPtr n; ReadProcessMemory(h, addr, b, (IntPtr)8, out n);
        return (IntPtr)BitConverter.ToInt64(b, 0);
    }
    public static string Get(int pid) {
        IntPtr h = OpenProcess(0x0410, false, pid); // QUERY_INFORMATION | VM_READ
        if (h == IntPtr.Zero) return null;
        try {
            var pbi = new IntPtr[6]; int ret;
            if (NtQueryInformationProcess(h, 0, pbi, 48, out ret) != 0) return null;
            IntPtr pp = ReadPtr(h, pbi[1] + 0x20);           // PEB.ProcessParameters
            IntPtr env = ReadPtr(h, pp + 0x80);              // Environment
            long size = ReadPtr(h, pp + 0x3F0).ToInt64();    // EnvironmentSize
            var buf = new byte[size]; IntPtr n;
            if (!ReadProcessMemory(h, env, buf, (IntPtr)size, out n)) return null;
            return Encoding.Unicode.GetString(buf);
        } finally { CloseHandle(h); }
    }
}
'@

$count = 0
foreach ($f in Get-ChildItem (Join-Path $env:USERPROFILE '.claude\sessions\*.json')) {
    $s = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
    if ($s.kind -ne 'interactive' -or -not $s.sessionId) { continue }
    if (-not (Get-Process -Id $s.pid -ErrorAction SilentlyContinue)) { continue }
    $envBlock = [ProcEnv]::Get([int]$s.pid)
    if ($envBlock -notmatch '(?m)(?:^|\0)WT_SESSION=([0-9a-fA-F-]{36})') { continue }
    Save-Pane $Matches[1] $s.sessionId $s.cwd
    $count++
    "{0,-36} {1}  {2}" -f $Matches[1], $s.sessionId, $s.cwd
}
"Recorded $count Claude pane(s) in $dir"
