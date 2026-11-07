# Shared menu foundation. Returns a choice; never invokes an item's action.
function Test-PcMenuKeyboard {
    try{return $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected}catch{return $false}
}
function ConvertFrom-PcMenuKey($Key) {
    switch([string]$Key.Key){
        'UpArrow'{return 'Up'} 'DownArrow'{return 'Down'}
        'Enter'{return 'Select'} 'Escape'{return 'Back'} 'Backspace'{return 'Back'}
        'PageUp'{return 'Previous'} 'PageDown'{return 'Next'}
        'Home'{return 'First'} 'End'{return 'Last'}
    }
    return [string]$Key.KeyChar
}
function Read-PcMenuKey { return [Console]::ReadKey($true) }
function Write-PcMenuSelection([string]$Digits) {
    Write-Host ("`rSelection: {0,-10}" -f ($Digits+'_')) -NoNewline -ForegroundColor Cyan
}
function Read-PcMenuInput([bool]$Keyboard) {
    if(-not $Keyboard){return Read-Host 'Number / Enter: select | B/0: back'}
    $digits=''
    Write-PcMenuSelection $digits
    try {
        while($true){
            $key=Read-PcMenuKey
            if($key.Key -eq 'Backspace' -and $digits.Length){$digits=$digits.Substring(0,$digits.Length-1);Write-PcMenuSelection $digits;continue}
            $value=ConvertFrom-PcMenuKey $key
            if($value -match '^\d$'){if($digits.Length -lt 9){$digits+=$value};Write-PcMenuSelection $digits;continue}
            if($value -eq 'Select' -and $digits.Length){return $digits}
            if($value -in @('Up','Down','Select','Back','Previous','Next','First','Last','f','r','b','n','p','a','c','l','e','d','m','x','s','t')){return $value}
        }
    } finally {Write-Host ''}
}
function Format-PcMenuText {
    param([AllowNull()][string]$Text,[int]$Width=100)
    $clean=($Text -replace '[\x00-\x1F\x7F]',' ')
    $Width=[math]::Max(4,$Width)
    if($clean.Length -le $Width){return $clean}
    $length=$Width-3
    if([char]::IsHighSurrogate($clean[$length-1])){$length--}
    return $clean.Substring(0,$length)+'...'
}
function Get-PcMenuHeading {
    param([string]$Title,[string]$Version='0.24.0')
    if($Title -eq 'Windows'){return "WINDOWS TOOLKIT $Version"}
    return "WINDOWS $Version | $Title"
}
function Get-PcMenuPageSize {
    param([int]$WindowHeight,[ValidateRange(1,3)][int]$DetailLines=1,[ValidateRange(1,100)][int]$Maximum=100)
    # Header, filter, page/status lines, controls and selection prompt use about six rows.
    # Keep three additional rows for wrapping and terminal variance without wasting a third of the viewport.
    $reservedRows=9
    return [int][math]::Max(1,[math]::Min($Maximum,[math]::Floor(($WindowHeight-$reservedRows)/[double]($DetailLines+1))))
}
function Write-PcMenuSegments {
    param([object[]]$Segments,[string]$Prefix='',[int]$Width=100,[string]$FallbackColor='Gray')
    $cleanPrefix=($Prefix -replace '[\x00-\x1F\x7F]',' ')
    $cleanSegments=@(foreach($segment in $Segments){
        [pscustomobject]@{Text=([string]$segment.Text -replace '[\x00-\x1F\x7F]',' ');Color=$(if($segment.Color){[string]$segment.Color}else{$FallbackColor})}
    })
    $bounded=Format-PcMenuText ($cleanPrefix+(($cleanSegments | ForEach-Object Text) -join '')) $Width
    $prefixLength=[math]::Min($cleanPrefix.Length,$bounded.Length)
    if($prefixLength){Write-Host $bounded.Substring(0,$prefixLength) -NoNewline -ForegroundColor $FallbackColor}
    $offset=$prefixLength
    foreach($segment in $cleanSegments){
        if($offset -ge $bounded.Length){break}
        $count=[math]::Min($segment.Text.Length,$bounded.Length-$offset)
        if($count){Write-Host $bounded.Substring($offset,$count) -NoNewline -ForegroundColor $segment.Color;$offset+=$count}
    }
    if($offset -lt $bounded.Length){Write-Host $bounded.Substring($offset) -NoNewline -ForegroundColor $FallbackColor}
    Write-Host ''
}
function Test-PcMenuCursorControl {
    try{return -not [Console]::IsOutputRedirected -and [Console]::CursorTop -ge 0}catch{return $false}
}
function Get-PcMenuCursorTop { return [Console]::CursorTop }
function Set-PcMenuCursorPosition([int]$Left,[int]$Top) { [Console]::SetCursorPosition($Left,$Top) }
function Clear-PcMenuRegion {
    param([int]$Top,[int]$Lines,[int]$Width)
    for($line=0;$line -lt $Lines;$line++){
        Set-PcMenuCursorPosition 0 ($Top+$line)
        Write-Host (' '*$Width) -NoNewline
    }
}
function Write-PcMenuDisplayItem {
    param($Row,[string]$DisplayKey,[bool]$Selected,[int]$Width,[int]$DetailLines,[switch]$ExpandedPreview,[switch]$Compact)
    $marker=if($Selected){'>'}else{' '}
    $kind=if($Row.Kind){' ['+$Row.Kind+']'}else{''}
    $color=if($Row.DisabledReason){'DarkGray'}elseif($Selected){'Cyan'}else{'Gray'}
    if($Row.LabelParts -and -not $Row.DisabledReason){
        $labelParts=@($Row.LabelParts)
        if($kind){$labelParts+=@([pscustomobject]@{Text=$kind;Color=$color})}
        Write-PcMenuSegments $labelParts ('{0} [{1}] ' -f $marker,$DisplayKey) $Width $color
    }else{Write-Host (Format-PcMenuText ('{0} [{1}] {2}{3}' -f $marker,$DisplayKey,$Row.Label,$kind) $Width) -ForegroundColor $color}
    $detail=if($Compact){@()}else{@($Row.Detail | Select-Object -First $DetailLines)}
    if($ExpandedPreview -and $Selected -and $Row.SelectedDetail){$detail=@($Row.SelectedDetail | Select-Object -First 3)}
    if($Row.DisabledReason){$detail=@('UNAVAILABLE: '+$Row.DisabledReason)}
    if(-not $Compact -and -not $detail.Count){$detail=@('')}
    for($detailIndex=0;$detailIndex -lt $detail.Count;$detailIndex++){
        if($detailIndex -eq 0 -and $Row.DetailParts -and -not $Row.DisabledReason -and -not ($ExpandedPreview -and $Selected -and $Row.SelectedDetail)){
            Write-PcMenuSegments @($Row.DetailParts) '    ' $Width $color
        }else{Write-Host (Format-PcMenuText ('    '+$detail[$detailIndex]) $Width) -ForegroundColor $color}
    }
    return 1+$detail.Count
}
function Show-PcMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [object[]]$Items=@(),
        [string]$Version='0.24.0',
        [string]$Description='',
        [hashtable]$State=@{},
        [switch]$Filterable,
        [switch]$Refreshable,
        [ValidateRange(1,100)][int]$PageSize=100,
        [switch]$Plain,
        [switch]$Compact,
        [string]$EmptyMessage='No matching items.',
        [hashtable]$Commands=@{},
        [ValidateRange(1,3)][int]$DetailLines=1,
        [switch]$ExpandedPreview
    )
    # Item contract: unique nonempty Id, Label; optional Kind, Detail, DisabledReason,
    # LabelParts and DetailParts arrays containing Text/Color objects.
    # Caller retains State and handles Select/Refresh/Back; no scriptblock is executed here.
    $ids=@{};$keys=@{};$displayKeys=@{};$ordinal=0
    foreach($item in $Items){
        if([string]::IsNullOrWhiteSpace([string]$item.Id) -or [string]::IsNullOrWhiteSpace([string]$item.Label)){throw 'Menu items require Id and Label.'}
        if($ids.ContainsKey([string]$item.Id)){throw "Duplicate menu item Id: $($item.Id)"}
        $ids[[string]$item.Id]=$true
        $ordinal++;$key=if($item.Key){[string]$item.Key}else{[string]$ordinal}
        if($key -notmatch '^(?:[1-9][0-9]*|[ACLED])$' -or $keys.ContainsKey($key)){throw "Invalid or duplicate menu key: $key"}
        $keys[$key]=[string]$item.Id;$displayKeys[[string]$item.Id]=$key
    }
    foreach($key in $Commands.Keys){if($key -notmatch '^[ACDEFLMSTX]$' -or $keys.ContainsKey($key) -or ($key -eq 'F' -and $Filterable)){throw "Invalid or conflicting menu command: $key"}}
    if(-not $State.ContainsKey('Filter')){$State.Filter=''}
    if(-not $State.ContainsKey('SelectedId')){$State.SelectedId=''}
    $keyboard=(-not $Plain -and (Test-PcMenuKeyboard));$notice=''
    while($true){
        $rows=@($Items | Where-Object {(-not $Filterable) -or (-not $State.Filter) -or (($_.Label+' '+($_.Detail -join ' ')+' '+$_.SearchText).IndexOf([string]$State.Filter,[StringComparison]::OrdinalIgnoreCase) -ge 0)})
        $selected=0
        for($i=0;$i -lt $rows.Count;$i++){if([string]$rows[$i].Id -eq $State.SelectedId){$selected=$i;break}}
        if($rows.Count){$State.SelectedId=[string]$rows[$selected].Id}
        $size=$PageSize;$width=100;$cursorControl=$false;$menuDetailLines=if($Compact){0}else{$DetailLines}
        if($keyboard){
            try{$size=Get-PcMenuPageSize $Host.UI.RawUI.WindowSize.Height $menuDetailLines $PageSize;$width=[math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1)}catch{}
            $cursorControl=Test-PcMenuCursorControl
            Clear-Host
        }
        $page=[int][math]::Floor($selected/[double]$size)
        Write-Host (Format-PcMenuText (Get-PcMenuHeading $Title $Version) $width) -ForegroundColor Cyan
        if($Description){Write-Host (Format-PcMenuText $Description $width)}
        if($Filterable){Write-Host (Format-PcMenuText ('Filter: '+$State.Filter) $width)}
        if(-not $rows.Count){Write-Host $EmptyMessage}
        $rowTops=@{};$rowHeights=@{}
        for($i=$page*$size;$i -lt [math]::Min($rows.Count,($page+1)*$size);$i++){
            if($cursorControl){$rowTops[$i]=Get-PcMenuCursorTop}
            $rowHeights[$i]=Write-PcMenuDisplayItem $rows[$i] $displayKeys[[string]$rows[$i].Id] ($i -eq $selected) $width $menuDetailLines -ExpandedPreview:$ExpandedPreview -Compact:$Compact
        }
        Write-Host ("Page {0}/{1} | {2} items" -f ($page+1),[math]::Max(1,[math]::Ceiling($rows.Count/[double]$size)),$rows.Count)
        $footer=if($keyboard){'Arrows: select | Enter: open | Esc/Backspace: back'}else{'Number/Enter: open | B/0: back'}
        if($rows.Count -gt $size){$footer+=' | N/P: pages'}
        if($Filterable){$footer+=' | F: filter'}
        if($Refreshable){$footer+=' | R: refresh'}
        Write-Host $footer
        if($Commands.Count){Write-Host (($Commands.Keys | Sort-Object | ForEach-Object {$_+': '+$Commands[$_]}) -join ' | ')}
        if($notice){Write-Warning $notice;$notice=''}
        while($true){
            $promptTop=if($cursorControl){Get-PcMenuCursorTop}else{-1}
            $answer=Read-PcMenuInput $keyboard
            if($null -eq $answer){return [pscustomobject]@{Action='Back';Item=$null;State=$State}}
            $choice=$answer.Trim();$open=$false;$navigated=$false;$oldSelected=$selected
            if($Commands.ContainsKey($choice)){return [pscustomobject]@{Action='Command';Command=$choice.ToUpperInvariant();Item=$null;State=$State}}
            switch($choice.ToUpperInvariant()){
                {$_ -in @('BACK','B','0')}{return [pscustomobject]@{Action='Back';Item=$null;State=$State}}
                'UP'{$selected=[math]::Max(0,$selected-1);$navigated=$true}
                'DOWN'{$selected=[math]::Min($rows.Count-1,$selected+1);$navigated=$true}
                'FIRST'{$selected=0;$navigated=$true} 'LAST'{$selected=$rows.Count-1;$navigated=$true}
                {$_ -in @('NEXT','N')}{$selected=[math]::Min($rows.Count-1,$selected+$size);$navigated=$true}
                {$_ -in @('PREVIOUS','P')}{$selected=[math]::Max(0,$selected-$size);$navigated=$true}
                'F'{
                    if($Filterable){$filter=Read-Host 'Filter contains [blank: all; B: cancel]';if($null -ne $filter -and $filter.Trim() -ne 'B'){$State.Filter=$filter}}
                    else{$notice='Filtering is not available in this menu.'}
                }
                'R'{if($Refreshable){return [pscustomobject]@{Action='Refresh';Item=$null;State=$State}}else{$notice='Refresh is not available in this menu.'}}
                {$_ -in @('SELECT','')}{$open=$true}
                default{
                    $match=-1
                    if($keys.ContainsKey($choice)){for($j=0;$j -lt $rows.Count;$j++){if([string]$rows[$j].Id -eq $keys[$choice]){$match=$j;break}}}
                    if($match -ge 0){$selected=$match;$open=$true}else{$notice='Choose a listed item or control.'}
                }
            }
            if($selected -ge 0 -and $selected -lt $rows.Count){
                $State.SelectedId=[string]$rows[$selected].Id
                if($open){
                    if($rows[$selected].DisabledReason){$notice=[string]$rows[$selected].DisabledReason}
                    else{return [pscustomobject]@{Action='Select';Item=$rows[$selected];State=$State}}
                }
            }
            if($navigated -and $rows.Count -and $selected -eq $oldSelected -and $cursorControl){
                try{Clear-PcMenuRegion $promptTop 2 $width;Set-PcMenuCursorPosition 0 $promptTop;continue}catch{$cursorControl=$false;break}
            }
            $newPage=if($rows.Count){[int][math]::Floor($selected/[double]$size)}else{0}
            $layoutMatches=$false
            if($cursorControl -and -not $ExpandedPreview -and $navigated -and $newPage -eq $page){
                try{$layoutMatches=([math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1) -eq $width -and (Get-PcMenuPageSize $Host.UI.RawUI.WindowSize.Height $menuDetailLines $PageSize) -eq $size)}catch{}
            }
            if($layoutMatches){
                try{
                    foreach($rowIndex in @($oldSelected,$selected | Select-Object -Unique)){
                        Clear-PcMenuRegion $rowTops[$rowIndex] $rowHeights[$rowIndex] $width
                        Set-PcMenuCursorPosition 0 $rowTops[$rowIndex]
                        $null=Write-PcMenuDisplayItem $rows[$rowIndex] $displayKeys[[string]$rows[$rowIndex].Id] ($rowIndex -eq $selected) $width $menuDetailLines -Compact:$Compact
                    }
                    Clear-PcMenuRegion $promptTop 2 $width;Set-PcMenuCursorPosition 0 $promptTop
                    continue
                }catch{$cursorControl=$false}
            }
            break
        }
    }
}
function Confirm-PcMenuChange {
    param([Parameter(Mandatory=$true)][string]$Description)
    Write-Host $Description
    return ((Read-Host 'Apply this change? [y/N]') -match '^(?i:y|yes)$')
}

function New-PcMenuItem {
    param([string]$Key,[string]$Label,[string]$Kind='Menu',[string]$Detail='', [string]$DisabledReason='')
    [pscustomobject]@{Id=$Key;Key=$Key;Label=$Label;Kind=$Kind;Detail=$Detail;DisabledReason=$DisabledReason}
}
function Read-PcCategoryMenu {
    param([string]$Title,[object[]]$Items,[hashtable]$State,[string[]]$Description=@())
    $keyboard=Test-PcMenuKeyboard;$selected=0
    for($i=0;$i -lt $Items.Count;$i++){if($Items[$i].Id -eq $State.SelectedId){$selected=$i;break}}
    while($true){
        $width=120
        if($keyboard){try{$width=[math]::Max(20,$Host.UI.RawUI.WindowSize.Width-1)}catch{};Clear-Host}
        Write-Host ("`n"+(Get-PcMenuHeading $Title)) -ForegroundColor Cyan
        foreach($line in $Description){if($line){Write-Host (Format-PcMenuText $line $width) -ForegroundColor DarkGray}}
        for($i=0;$i -lt $Items.Count;$i++){
            $item=$Items[$i]
            $color=if($keyboard -and $i -eq $selected){'Cyan'}elseif($item.DisabledReason){'DarkGray'}elseif($item.Kind -eq 'Change'){'Yellow'}else{'Gray'}
            $marker=if($keyboard -and $i -eq $selected){'>'}else{' '}
            $label='{0} [{1}] {2}' -f $marker,$item.Key,$item.Label
            if($item.Kind -eq 'Change'){$label+=' [CHANGES SYSTEM]'}
            if($item.DisabledReason){$label+=' [UNAVAILABLE: '+$item.DisabledReason+']'}
            elseif($item.Detail){$label+=' - '+($item.Detail -join ' ')}
            Write-Host (Format-PcMenuText $label $width) -ForegroundColor $color
        }
        if($keyboard){Write-Host 'Arrows + Enter or number + Enter | Esc/Backspace/B/0: back'}
        else{Write-Host 'Number + Enter | B / 0: back'}
        $answer=Read-PcMenuInput $keyboard
        if($null -eq $answer -or $answer.Trim() -in @('Back','B','0')){return 'B'}
        $item=$null
        switch($answer.Trim().ToUpperInvariant()){
            'UP'{$selected=[math]::Max(0,$selected-1)}
            'DOWN'{$selected=[math]::Min($Items.Count-1,$selected+1)}
            'FIRST'{$selected=0} 'LAST'{$selected=$Items.Count-1}
            {$_ -in @('SELECT','')}{if($Items.Count){$item=$Items[$selected]}}
            default{$item=$Items | Where-Object Key -EQ $answer.Trim() | Select-Object -First 1;if(-not $item){Write-Warning 'Choose a listed number or shortcut.';Wait-PcMenuReturn}}
        }
        if($selected -ge 0 -and $selected -lt $Items.Count){$State.SelectedId=[string]$Items[$selected].Id}
        if(-not $item){continue}
        for($i=0;$i -lt $Items.Count;$i++){if($Items[$i].Id -eq $item.Id){$selected=$i;break}}
        $State.SelectedId=[string]$item.Id
        if($item.DisabledReason){Write-Warning $item.DisabledReason;Wait-PcMenuReturn;continue}
        $State.SelectedId=[string]$item.Id
        return [string]$item.Id
    }
}
function Wait-PcMenuReturn {
    if(Test-PcMenuKeyboard){$null=Read-Host 'Enter to return'}
}

function Show-PcListDetails {
    param($Row,[string]$Title='Details')
    Write-Host ("`n"+$Title) -ForegroundColor Cyan
    $Row | Format-List * | Out-Host
    while($true){
        Write-Host 'Enter / Esc / Backspace / B: back'
        $answer=Read-PcMenuInput (Test-PcMenuKeyboard)
        if($null -eq $answer -or $answer.Trim() -in @('','Select','Back','B','0')){return}
    }
}
