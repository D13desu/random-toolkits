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
        [pscustomobject]@{Key='9';Id='zoomit';Name='ZoomIt';Detail='Screen zoom, annotation and presentation timer';x86='ZoomIt.exe';x64='ZoomIt64.exe';arm64='ZoomIt64a.exe'}
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

function Start-PcSysinternalsLiveTool([string]$Id) {
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
