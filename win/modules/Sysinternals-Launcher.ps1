# Shortcuts to Microsoft's Sysinternals Live WebDAV share. No binaries are downloaded or redistributed.
$script:PcSysinternalsLiveRoot='\\live.sysinternals.com\tools'

function Get-PcSysinternalsArchitecture {
    $architecture=[string]$env:PROCESSOR_ARCHITEW6432
    if(-not $architecture){$architecture=[string]$env:PROCESSOR_ARCHITECTURE}
    if($architecture -match 'ARM64'){return 'arm64'}
    if($architecture -match 'AMD64'){return 'x64'}
    return 'x86'
}

function Get-PcSysinternalsLiveCatalog {
    @(
        [pscustomobject]@{Key='1';Id='procexp';Name='Process Explorer';Detail='Processes, handles, DLLs and system activity';x86='procexp.exe';x64='procexp64.exe';arm64='procexp64a.exe'}
        [pscustomobject]@{Key='2';Id='procmon';Name='Process Monitor';Detail='Live file, Registry, process and network events';x86='Procmon.exe';x64='Procmon64.exe';arm64='Procmon64a.exe'}
        [pscustomobject]@{Key='3';Id='autoruns';Name='Autoruns';Detail='Logon, service, driver and extension persistence';x86='Autoruns.exe';x64='Autoruns64.exe';arm64='Autoruns64a.exe'}
        [pscustomobject]@{Key='4';Id='tcpview';Name='TCPView';Detail='Live TCP and UDP endpoints with owning processes';x86='tcpview.exe';x64='tcpview64.exe';arm64='tcpview64a.exe'}
        [pscustomobject]@{Key='5';Id='rammap';Name='RAMMap';Detail='Physical-memory usage and cache inspection';x86='RAMMap.exe';x64='RAMMap64.exe';arm64='RAMMap64a.exe'}
        [pscustomobject]@{Key='6';Id='winobj';Name='WinObj';Detail='Windows Object Manager namespace viewer';x86='Winobj.exe';x64='Winobj64.exe';arm64='Winobj64a.exe'}
        [pscustomobject]@{Key='7';Id='vmmap';Name='VMMap';Detail='Detailed virtual and physical process memory map';x86='vmmap.exe';x64='vmmap64.exe';arm64='vmmap64a.exe'}
        [pscustomobject]@{Key='8';Id='dbgview';Name='DebugView';Detail='Capture local and kernel debug output';x86='Dbgview.exe';x64='Dbgview64.exe';arm64='Dbgview64a.exe'}
        [pscustomobject]@{Key='9';Id='accesschk';Name='AccessChk';Detail='Inspect effective permissions on files, Registry keys, services and processes';x86='accesschk.exe';x64='accesschk64.exe';arm64='accesschk64a.exe'}
        [pscustomobject]@{Key='10';Id='disk2vhd';Name='Disk2vhd';Detail='Create VHD images of selected physical volumes';x86='disk2vhd.exe';x64='disk2vhd64.exe';arm64='disk2vhd64a.exe'}
    )
}

function Get-PcSysinternalsLivePath([string]$Id) {
    $tool=Get-PcSysinternalsLiveCatalog | Where-Object Id -EQ $Id | Select-Object -First 1
    if(-not $tool){throw "Unknown Sysinternals tool: $Id"}
    $architecture=Get-PcSysinternalsArchitecture
    $file=[string]$tool.$architecture
    if([string]::IsNullOrWhiteSpace($file)){throw "$($tool.Name) has no $architecture Sysinternals Live shortcut."}
    $directory=if($architecture -eq 'arm64'){$script:PcSysinternalsLiveRoot+'\ARM64'}else{$script:PcSysinternalsLiveRoot}
    [pscustomobject]@{Tool=$tool;Path=($directory+'\'+$file);Architecture=$architecture}
}

function New-PcAccessChkArguments {
    param([string]$Account,[string]$Path,[ValidateSet('All','Read','Write')][string]$Access='All',[switch]$Recurse)
    $Account=$Account.Trim();$Path=$Path.Trim()
    if(-not $Account -or $Account -match '^[/-]|["\x00-\x1f]'){throw 'Enter a user or group such as DOMAIN\user, COMPUTER\user or Everyone.'}
    if($Path -notmatch '^(?:[A-Za-z]:\\|\\\\[^\\]+\\[^\\]+)' -or $Path -match '["*?\x00-\x1f]'){throw 'Enter an absolute file/folder path (C:\Data or \\server\share\Data), without quotes or wildcards.'}
    # Avoid Windows PowerShell native quoting ambiguity for a trailing backslash.
    if($Path.EndsWith('\')){$Path+='.'}
    $arguments=@('-v')
    if($Access -eq 'Read'){$arguments+='-r'}
    if($Access -eq 'Write'){$arguments+='-w'}
    if($Recurse){$arguments+='-s'}
    $arguments+=$Account;$arguments+=$Path
    return $arguments
}

function Invoke-PcAccessChk([string]$Executable,[string[]]$Arguments) {
    # Pass data directly to the executable, never through cmd.exe or Invoke-Expression.
    & $Executable @Arguments | Out-Host
    return $LASTEXITCODE
}

function Start-PcAccessChk {
    Write-Host "`nAccessChk file/folder permissions (read-only)" -ForegroundColor Cyan
    Write-Host 'Enter B at any prompt to return. Output reports effective access for the specified account.'
    $account=Read-Host 'User or group (DOMAIN\user, COMPUTER\user, or Everyone)'
    if($null -eq $account -or $account.Trim() -eq 'B'){return}
    $path=Read-Host 'Absolute file/folder path (without surrounding quotes)'
    if($null -eq $path -or $path.Trim() -eq 'B'){return}
    $choice=Read-Host 'Access: [1] All permissions (R/W) [2] Read [3] Write (default 1)'
    if($null -eq $choice -or $choice.Trim() -eq 'B'){return}
    $access=switch($choice.Trim()){'2'{'Read'}'3'{'Write'}{$_ -in @('','1')}{'All'}default{throw 'Choose 1, 2 or 3.'}}
    $recursive=Read-Host 'Recurse into subfolders? [y/N]'
    if($null -eq $recursive -or $recursive.Trim() -eq 'B'){return}
    if($recursive.Trim() -notmatch '^(?i:y|yes|n|no)?$'){throw 'Choose Y or N.'}
    $arguments=@(New-PcAccessChkArguments -Account $account -Path $path -Access $access -Recurse:($recursive.Trim() -match '^(?i:y|yes)$'))
    $resolved=Get-PcSysinternalsLivePath 'accesschk'
    Write-Host ('Executable: '+$resolved.Path) -ForegroundColor DarkGray
    Write-Host ('Arguments: '+(($arguments | ForEach-Object {'"'+$_+'"'}) -join ' ')) -ForegroundColor DarkGray
    Write-Host 'R = read, W = write; verbose output lists specific rights. Filtered/empty output is not proof of denial if the command reports an error.'
    Write-Host 'UNC checks do not separately establish SMB share permissions. Microsoft EULA prompts remain enabled.' -ForegroundColor Yellow
    try{
        $exitCode=Invoke-PcAccessChk $resolved.Path $arguments
        Write-Host "AccessChk exit code: $exitCode"
    }finally{
        $null=Read-Host 'Press Enter to return'
    }
}

function Start-PcSysinternalsLiveTool([string]$Id) {
    if($Id -eq 'accesschk'){Start-PcAccessChk;return}
    $resolved=Get-PcSysinternalsLivePath $Id
    Write-Host "Opening $($resolved.Tool.Name) from Microsoft's Sysinternals Live share..." -ForegroundColor Cyan
    Write-Host $resolved.Path -ForegroundColor DarkGray
    Start-Process -FilePath $resolved.Path -ErrorAction Stop
    Write-Host 'The executable remains hosted by Microsoft. Its EULA and elevation prompts are not bypassed.' -ForegroundColor Green
}

function Show-PcSysinternalsLiveNotes {
    Clear-PcMenuScreen
    Write-Host "`nMicrosoft Sysinternals Live" -ForegroundColor Cyan
    Write-Host 'Share: \\live.sysinternals.com\tools'
    Write-Host 'Browser: https://live.sysinternals.com/'
    Write-Host 'Documentation: https://learn.microsoft.com/sysinternals/'
    Write-Host 'Each shortcut runs the current Microsoft-hosted executable over the network; nothing is installed or cached by this toolkit.'
    Write-Host 'A working internet connection and Windows WebDAV access are required. Corporate policy, proxy settings, or the WebClient service can block the share.' -ForegroundColor Yellow
    Write-Host 'Tools may request elevation and EULA acceptance. Captured diagnostics can contain sensitive system information.' -ForegroundColor Yellow
    $null=Read-Host 'Press Enter to return'
}

function Start-PcSysinternalsMenu {
    $state=@{}
    while($true){
        $menu=@(Get-PcSysinternalsLiveCatalog | ForEach-Object {New-PcMenuItem $_.Key $_.Name 'Open' $_.Detail})
        $menu+=New-PcMenuItem 'F' 'Open the Sysinternals Live tools share' 'Open' '\\live.sysinternals.com\tools'
        $menu+=New-PcMenuItem 'L' 'Network-share, EULA and safety notes' 'Check'
        $answer=Read-PcCategoryMenu 'Windows > Microsoft Sysinternals Live' $menu $state 'Microsoft-hosted network shortcuts; no toolkit download or local cache.'
        if($null -eq $answer -or $answer -in @('0','B')){return}
        try{
            $tool=Get-PcSysinternalsLiveCatalog | Where-Object Key -EQ $answer | Select-Object -First 1
            if($tool){Start-PcSysinternalsLiveTool $tool.Id;continue}
            switch($answer){
                'F'{Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$script:PcSysinternalsLiveRoot+'"') -ErrorAction Stop}
                'L'{Show-PcSysinternalsLiveNotes}
            }
        }catch{
            Write-Host "Sysinternals Live shortcut failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host 'Try https://live.sysinternals.com/ in a browser, or check whether WebDAV/Sysinternals Live is allowed by your network policy.' -ForegroundColor Yellow
            $null=Read-Host 'Press Enter to return'
        }
    }
}
