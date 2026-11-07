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
        'F1' { return '@REPORTS' }
    }
    return ([string]$Key.KeyChar).ToUpperInvariant()
}
function Read-HelperChoice([bool]$Keyboard,[bool]$Live=$false,[int]$LiveIntervalMilliseconds=2000) {
    if (-not $Keyboard) { return Read-Host 'Select' }
    $digits=''
    $timer=if($Live){[Diagnostics.Stopwatch]::StartNew()}else{$null}
    while ($true) {
        if($Live -and -not [Console]::KeyAvailable){
            if($timer.ElapsedMilliseconds -ge $LiveIntervalMilliseconds -and -not $digits.Length){return '@LIVE_TICK'}
            Start-Sleep -Milliseconds 50
            continue
        }
        $key=[Console]::ReadKey($true)
        if ($key.Key -eq 'Backspace' -and $digits.Length) { $digits=$digits.Substring(0,$digits.Length-1); continue }
        $command=ConvertFrom-HelperKey $key
        if ($command -match '^\d$') { $digits+=$command; continue }
        if ($command -eq '@ENTER' -and $digits.Length) { return $digits }
        if ($command -in @('@UP','@DOWN','@ENTER','@EXPLORER','@REPORTS','H','B','U','N','P','S','E','A','T','O','L','R')) { return $command }
    }
}
function Read-HelperReport([bool]$Keyboard) {
    $labels=@('Space accounting','Scan diagnostics','Timing and memory')
    $commands=@('A','E','T');$selected=0
    while($true){
        if($Keyboard){Clear-Host}
        Write-Host "`nREPORTS" -ForegroundColor Cyan
        for($i=0;$i -lt $labels.Count;$i++){
            $marker=if($i -eq $selected){'>'}else{' '}
            Write-Host ('{0} [{1}] {2}' -f $marker,($i+1),$labels[$i])
        }
        if($Keyboard){Write-Host 'Up/Down: select | Enter: view | Esc: back'}
        else{Write-Host 'Number: view | B / 0: back'}
        $choice=Read-HelperChoice $Keyboard
        switch(([string]$choice).Trim().ToUpperInvariant()){
            '@UP'{$selected=[math]::Max(0,$selected-1)}
            '@DOWN'{$selected=[math]::Min(2,$selected+1)}
            '@ENTER'{return $commands[$selected]}
            '1'{return 'A'} '2'{return 'E'} '3'{return 'T'}
            'B'{return ''} '0'{return ''}
        }
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

function Test-HelperElevated {
    $principal=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-HelperVolumeInfo([string]$Root) { return [IO.DriveInfo]::new($Root) }
function Get-HelperAvailableBytes([string]$Path) {
    try {
        $root=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
        $drive=Get-HelperVolumeInfo $root
        if($drive.IsReady){return [long]$drive.AvailableFreeSpace}
    } catch {}
    return $null
}
function Get-HelperScanEngine {
    param([string]$Path,[ValidateSet('auto','mft','native')][string]$Requested='auto')
    if($Requested -ne 'auto'){return $Requested}
    $full=[IO.Path]::GetFullPath($Path)
    $root=[IO.Path]::GetPathRoot($full)
    if($root -match '^[A-Za-z]:\\$' -and $full.TrimEnd('\') -eq $root.TrimEnd('\') -and (Test-HelperElevated)){
        try{$drive=Get-HelperVolumeInfo $root;if($drive.IsReady -and $drive.DriveType -eq 'Fixed' -and $drive.DriveFormat -eq 'NTFS'){return 'mft'}}catch{}
    }
    return 'native'
}
