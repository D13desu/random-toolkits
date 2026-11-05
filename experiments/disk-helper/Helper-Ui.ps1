function Test-HelperConsole {
    try { return $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected } catch { return $false }
}
function ConvertFrom-HelperKey($Key) {
    switch ([string]$Key.Key) {
        'UpArrow' { return '@UP' }
        'DownArrow' { return '@DOWN' }
        'LeftArrow' { return 'B' }
        'Backspace' { return 'B' }
        'Escape' { return 'B' }
        'RightArrow' { return '@ENTER' }
        'Enter' { if (($Key.Modifiers -band [ConsoleModifiers]::Control) -ne 0) { return '@EXPLORER' }; return '@ENTER' }
        'PageDown' { return 'N' }
        'PageUp' { return 'P' }
    }
    return ([string]$Key.KeyChar).ToUpperInvariant()
}
function Read-HelperChoice([bool]$Keyboard) {
    if (-not $Keyboard) { return Read-Host 'Select (number; O: open selected directory in Explorer)' }
    $digits=''
    while ($true) {
        $key=[Console]::ReadKey($true)
        if ($key.Key -eq 'Backspace' -and $digits.Length) { $digits=$digits.Substring(0,$digits.Length-1); continue }
        $command=ConvertFrom-HelperKey $key
        if ($command -match '^\d$') { $digits+=$command; continue }
        if ($command -eq '@ENTER' -and $digits.Length) { return $digits }
        if ($command -in @('@UP','@DOWN','@ENTER','@EXPLORER','B','U','N','P','S','E','A','T','O')) { return $command }
    }
}
function Open-HelperDirectory([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path) -or -not [IO.Directory]::Exists($Path)) { throw 'This directory no longer exists or is inaccessible.' }
    $full=[IO.Path]::GetFullPath($Path)
    # Quote a single directory argument. Appending dot avoids a trailing backslash
    # immediately before the closing quote, including for volume roots.
    $argument='"'+$full.TrimEnd('\')+'\.'+'"'
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList $argument -ErrorAction Stop
}
