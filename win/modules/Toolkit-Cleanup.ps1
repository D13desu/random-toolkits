function Get-ToolkitCleanupRoots {
    [pscustomobject]@{Temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\');Data=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Random-Toolkits')).TrimEnd('\')}
}
function Assert-ToolkitCleanupPath([string]$Path,[string]$Root) {
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\');$boundary=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    if(-not $full.StartsWith($boundary+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path is outside the cleanup boundary.'}
    $cursor=$full
    while($cursor){
        if(Test-Path -LiteralPath $cursor){$entry=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop;if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Links/reparse points are excluded.'}}
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
}
function Get-ToolkitCleanupTree([string]$Path,[string]$Root) {
    Assert-ToolkitCleanupPath $Path $Root
    $pending=New-Object 'Collections.Generic.Stack[string]';$pending.Push($Path)
    $entries=New-Object 'Collections.Generic.List[object]'
    while($pending.Count){
        $item=Get-Item -LiteralPath $pending.Pop() -Force -ErrorAction Stop
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Contains a link/reparse point; skipped without following it.'}
        if($item.LastWriteTimeUtc -gt [datetime]::UtcNow.AddMinutes(-10)){throw 'Recently modified (within 10 minutes); may still be in use.'}
        $entries.Add([pscustomobject]@{Path=$item.FullName;Directory=$item.PSIsContainer;Bytes=$(if($item.PSIsContainer){0L}else{$item.Length});Stamp=$item.LastWriteTimeUtc.Ticks})
        if($item.PSIsContainer){foreach($child in (Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop)){$pending.Push($child.FullName)}}
    }
    return $entries.ToArray()
}
function Get-ToolkitCleanupCandidates {
    param([ValidateSet('Temp','Cache','Both')][string]$Scope='Temp')
    $roots=Get-ToolkitCleanupRoots;$targets=New-Object 'Collections.Generic.List[object]'
    if($Scope -ne 'Cache'){
        foreach($item in (Get-ChildItem -LiteralPath $roots.Temp -Force -ErrorAction Stop)){
            $kind=''
            if($item.Name -match '^toolkit-disk-[a-f0-9]{32}\.ps1$'){$kind='Temporary script'}
            elseif($item.Name -match '^toolkit-helper-[a-f0-9]{32}$'){$kind='Helper package / fixture'}
            elseif($item.Name -match '^(?:toolkit-(?:helper-compare|disk-test|long-test|disk-benchmark|allocation|mft-live|wof)|helper-navigation|helper keyboard |oui-test|cleanup-safety-test)[-]?[a-f0-9]{32}$'){$kind='Test fixture'}
            elseif($item.Name -match '^toolkit-(?:helper|launcher)-[a-z0-9-]+\.json$'){$kind='Diagnostic report (may contain local paths)'}
            elseif($item.Name -match '^discovery-test-[a-f0-9]{32}\.csv$'){$kind='Discovery test export'}
            if($kind){$targets.Add([pscustomobject]@{Path=$item.FullName;Root=$roots.Temp;Kind=$kind})}
        }
    }
    if($Scope -ne 'Temp'){
        $oui=Join-Path $roots.Data 'oui'
        if(Test-Path -LiteralPath $oui){$targets.Add([pscustomobject]@{Path=$oui;Root=$roots.Data;Kind='Public IEEE cache'})}
        $m365=Join-Path $roots.Data 'm365'
        if(Test-Path -LiteralPath $m365){
            Assert-ToolkitCleanupPath $m365 $roots.Data
            foreach($version in (Get-ChildItem -LiteralPath $m365 -Directory -Force -ErrorAction Stop)){
                if($version.Name -notmatch '^\d+\.\d+\.\d+$' -or ($version.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
                foreach($file in (Get-ChildItem -LiteralPath $version.FullName -File -Force -ErrorAction Stop)){
                    if($file.Name -eq 'M365-Toolkit.ps1' -or $file.Name -match '^\.download-[a-f0-9]{32}\.ps1$'){$targets.Add([pscustomobject]@{Path=$file.FullName;Root=$roots.Data;Kind='Cached M365 script'})}
                }
            }
        }
    }
    $helperRunning=@(Get-Process DiskHelper -ErrorAction SilentlyContinue).Count -gt 0
    foreach($target in $targets){
        $reason='';$entries=@();$bytes=0L
        try{
            if($helperRunning -and $target.Kind -eq 'Helper package / fixture'){throw 'A DiskHelper process is running; packages are retained.'}
            $entries=@(Get-ToolkitCleanupTree $target.Path $target.Root)
            foreach($entry in $entries){$bytes+=$entry.Bytes}
        }catch{$reason=$_.Exception.Message}
        [pscustomobject]@{Path=$target.Path;Root=$target.Root;Kind=$target.Kind;Bytes=$bytes;Eligible=($reason -eq '');Reason=$reason;Entries=$entries}
    }
}
function Remove-ToolkitCleanupCandidate($Candidate,[string]$Scope) {
    # Re-discover ownership and contents after confirmation; never trust a supplied path alone.
    $current=@(Get-ToolkitCleanupCandidates $Scope | Where-Object {$_.Path -eq $Candidate.Path})
    if($current.Count -ne 1 -or -not $current[0].Eligible){throw 'Target is no longer eligible; rescan the cleanup preview.'}
    $before=($Candidate.Entries | Sort-Object Path | ForEach-Object {"$($_.Path)|$($_.Directory)|$($_.Bytes)|$($_.Stamp)"}) -join "`n"
    $after=($current[0].Entries | Sort-Object Path | ForEach-Object {"$($_.Path)|$($_.Directory)|$($_.Bytes)|$($_.Stamp)"}) -join "`n"
    if($before -cne $after){throw 'Contents changed since preview; skipped.'}
    foreach($entry in ($current[0].Entries | Sort-Object @{Expression={$_.Path.Length};Descending=$true})){
        Assert-ToolkitCleanupPath $entry.Path $current[0].Root
        # Nonrecursive deletion: a newly added child prevents directory deletion.
        if($entry.Directory){[IO.Directory]::Delete($entry.Path,$false)}
        else{Remove-Item -LiteralPath $entry.Path -Force -ErrorAction Stop}
    }
}
function Start-ToolkitCleanup {
    $state=@{}
    while($true){
        $menu=@(
            New-PcMenuItem '1' 'Temporary packages, diagnostic reports and test fixtures' 'Change' 'Preview before confirmation'
            New-PcMenuItem '2' 'Download caches' 'Change' 'IEEE and cached M365 scripts; preview first'
            New-PcMenuItem '3' 'Temporary files and download caches' 'Change' 'Preview both'
        )
        $answer=Read-PcCategoryMenu 'Windows > Toolkit cleanup' $menu $state 'Current account only. User exports, reports, registry undo files and sign-in sessions are retained.'
        if($answer -in @('B','0') -or $null -eq $answer){return}
        $scope=switch($answer){'1'{'Temp'}'2'{'Cache'}'3'{'Both'}default{''}}
        if(-not $scope){continue}
        Clear-PcMenuScreen
        try{
            $items=@(Get-ToolkitCleanupCandidates $scope)
            if(-not $items.Count){Write-Host 'No recognized cleanup candidates found.';continue}
            $items | Select-Object Path,Kind,Bytes,Eligible,Reason | Format-List | Out-Host
            $eligible=@($items | Where-Object Eligible);$size=($eligible | Measure-Object Bytes -Sum).Sum
            Write-Host ("Eligible: {0} items, {1:N2} MiB. Skipped items remain. Deletion is permanent, not a secure erase." -f $eligible.Count,($size/1MB))
            if(-not $eligible.Count){continue}
            if((Read-Host 'Delete only the eligible items listed above? [y/N]') -notmatch '^(?i:y|yes)$'){continue}
            foreach($item in $eligible){
                try{Remove-ToolkitCleanupCandidate $item $scope;Write-Host ('Removed: '+$item.Path)}
                catch{Write-Warning ("Retained or partially removed: {0}: {1}" -f $item.Path,$_.Exception.Message)}
            }
        }catch{Write-Warning $_.Exception.Message}finally{Wait-PcMenuReturn}
    }
}
