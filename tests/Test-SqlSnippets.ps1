$ErrorActionPreference = 'Stop'

# Load the authoritative version before importing menu functions.
$script:PcToolkitVersion = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '../win/VERSION') -Raw).Trim()

. (Join-Path $PSScriptRoot '../win/modules/Menu-Engine.ps1')
. (Join-Path $PSScriptRoot '../win/modules/Sql-Snippets.ps1')

function Assert($ok, $message) {
    if (-not $ok) { throw "FAIL: $message" }
    Write-Output "PASS: $message"
}

function AssertThrows([scriptblock]$Action, [string]$message) {
    $threw = $false
    try { & $Action } catch { $threw = $true }
    Assert $threw $message
}

# --- Registry integrity (independent of the sync-time validation) ---
$registry = @(. (Join-Path $PSScriptRoot '../win/sql/snippets.ps1'))
Assert ($registry.Count -eq 32) 'Registry declares 32 snippets'
$ids = @($registry | ForEach-Object { [string]$_.Id })
Assert (($ids | Select-Object -Unique).Count -eq $ids.Count) 'Snippet identifiers are unique'
Assert (@($registry | Where-Object { [string]$_.Type -notin @('READ-ONLY', 'MODIFICATION') }).Count -eq 0) 'Every snippet type is READ-ONLY or MODIFICATION'
$known = @('users', 'health', 'performance', 'maintenance', 'connections', 'troubleshooting')
Assert (@($registry | Where-Object { [string]$_.Category -notin $known }).Count -eq 0) 'Every snippet uses a known category'
Assert (@($registry | Where-Object { -not $_.Scope -or -not $_.Permissions -or -not $_.Compatibility -or -not $_.Cost }).Count -eq 0) 'Every snippet has operational metadata'

$missingFile = 0
$undeclared = 0
foreach ($snippet in $registry) {
    $sqlPath = Join-Path $PSScriptRoot ('../win/sql/' + [string]$snippet.SqlFile)
    if (-not [IO.File]::Exists($sqlPath)) { $missingFile++; continue }
    $sql = [IO.File]::ReadAllText($sqlPath)
    $declared = @{}
    foreach ($p in @($snippet.Parameters)) { $declared[[string]$p.Name] = $true }
    foreach ($m in [regex]::Matches($sql, '\{\{([A-Za-z][A-Za-z0-9]*)\}\}')) {
        if (-not $declared.ContainsKey([string]$m.Groups[1].Value)) { $undeclared++ }
    }
}
Assert ($missingFile -eq 0) 'Every registered SQL file exists'
Assert ($undeclared -eq 0) 'Every {{token}} has a declared parameter'

# --- Escaping ---
Assert ((ConvertTo-PcSqlIdentifier 'MyDB') -eq '[MyDB]') 'Identifier is bracket-wrapped'
Assert ((ConvertTo-PcSqlIdentifier 'a]b') -eq '[a]]b]') 'Embedded closing bracket is doubled'
Assert ((ConvertTo-PcSqlLiteral "O'Brien") -eq "N'O''Brien'") 'Literal doubles embedded single quotes'
Assert ((ConvertTo-PcSqlLiteral $null) -eq 'NULL') 'Null literal renders as NULL'
Assert ((ConvertTo-PcSqlLiteral 'x') -eq "N'x'") 'Literal is N-prefixed and quoted'
$identParam = [pscustomobject]@{ Name = 'Db'; Default = 'x'; Kind = 'Identifier' }
Assert ((ConvertTo-PcSqlParameterValue $identParam 'a]b') -eq '[a]]b]') 'Identifier parameter is bracket-escaped'
$literalParam = [pscustomobject]@{ Name = 'Pattern'; Default = ''; Kind = 'Literal' }
Assert ((ConvertTo-PcSqlParameterValue $literalParam "O'Reilly") -eq "N'O''Reilly'") 'Literal parameter is escaped and N-quoted'
$integerParam = [pscustomobject]@{ Name = 'N'; Default = '5'; Kind = 'Integer'; Min = '1'; Max = '10' }
Assert ((ConvertTo-PcSqlParameterValue $integerParam '7') -eq '7') 'Integer parameter is substituted unquoted'
AssertThrows { ConvertTo-PcSqlParameterValue $integerParam '7; DROP TABLE x' } 'Integer parameter rejects SQL text'
AssertThrows { ConvertTo-PcSqlParameterValue $integerParam '0' } 'Integer parameter enforces its minimum'
AssertThrows { ConvertTo-PcSqlParameterValue $integerParam '11' } 'Integer parameter enforces its maximum'
$decimalParam = [pscustomobject]@{ Name = 'Ratio'; Default = '1.5'; Kind = 'Decimal'; Min = '0'; Max = '2' }
Assert ((ConvertTo-PcSqlParameterValue $decimalParam '1.25') -eq '1.25') 'Decimal parameter uses invariant SQL formatting'
AssertThrows { ConvertTo-PcSqlParameterValue $decimalParam '1,25' } 'Decimal parameter rejects locale-dependent separators'
$enumParam = [pscustomobject]@{ Name = 'Mode'; Default = 'LIMITED'; Kind = 'Enum'; AllowedValues = @('LIMITED','SAMPLED','DETAILED') }
Assert ((ConvertTo-PcSqlParameterValue $enumParam 'SAMPLED') -eq 'SAMPLED') 'Enum parameter accepts an allowed value'
AssertThrows { ConvertTo-PcSqlParameterValue $enumParam 'LIMITED; DROP TABLE x' } 'Enum parameter rejects values outside its allowlist'
AssertThrows { ConvertTo-PcSqlParameterValue $identParam '' } 'Identifier parameters cannot be empty'

# --- Parameter substitution ---
$fix = Get-PcSqlSnippet 'fix-orphaned-users'
$sql = Expand-PcSqlSnippet $fix @{}
Assert ($sql -match 'USE \[YourDatabase\]') 'Default parameter value is substituted as an identifier'
Assert ($sql -match 'ALTER USER \[YourUser\]') 'Multiple identifiers substitute independently'
Assert ($sql -match 'WITH LOGIN = \[YourLogin\]') 'Login parameter substitutes'
Assert ($sql -notmatch '\{\{') 'No unresolved tokens remain'
$custom = Expand-PcSqlSnippet $fix @{ Database = 'My DB'; User = 'u]1'; Login = 'l' }
Assert ($custom -match 'USE \[My DB\]') 'Spaces in identifiers are preserved inside brackets'
Assert ($custom -match 'ALTER USER \[u\]\]1\]') 'Closing bracket in a value is escaped'
$lq = Get-PcSqlSnippet 'long-running-queries'
$expandedThreshold = Expand-PcSqlSnippet $lq @{ ThresholdMinutes = '30' }
Assert ($expandedThreshold -match '> 30 \* 60000') 'Integer parameter is substituted unquoted'
AssertThrows { Expand-PcSqlSnippet $lq @{ ThresholdMinutes = '5; SELECT 1' } } 'Snippet expansion rejects unsafe numeric input'
Assert ((Get-PcSqlSnippet 'does-not-exist') -eq $null) 'Unknown snippet id resolves to nothing'
foreach ($newId in @('blocking-chain','database-free-space','long-running-transactions','backup-compliance')) {
    Assert ($null -ne (Get-PcSqlSnippet $newId)) "New v0.28.0 snippet is registered: $newId"
}

# --- Type classification in menu items ---
$modItem = New-PcSqlSnippetMenuItem $fix
$roItem = New-PcSqlSnippetMenuItem (Get-PcSqlSnippet 'orphaned-users')
Assert ($modItem.LabelParts[1].Text -match 'MODIFICATION') 'Modification snippet is labelled'
Assert ($modItem.LabelParts[1].Color -eq 'Yellow') 'Modification snippet is highlighted'
Assert ($roItem.LabelParts[1].Text -match 'READ-ONLY') 'Read-only snippet is labelled'
Assert ($roItem.LabelParts[1].Color -eq 'Green') 'Read-only snippet is green'
Assert ($modItem.Data.Id -eq 'fix-orphaned-users') 'Menu item carries its snippet'

# --- Category order ---
$cats = @(Get-PcSqlSnippetCategories)
Assert ($cats.Count -eq 6) 'Six categories are defined'
Assert ((@($cats.Id) -join ',') -eq 'users,health,performance,maintenance,connections,troubleshooting') 'Categories follow the documented order'

# --- Detail view: display, warning, and clipboard ---
$script:Out = New-Object 'Collections.Generic.List[string]'
$script:Warn = New-Object 'Collections.Generic.List[string]'
$script:Clip = $null
$script:Answers = New-Object 'Collections.Generic.Queue[string]'
function Write-Host { param($Object, $ForegroundColor, [switch]$NoNewline) $script:Out.Add([string]$Object) }
function Write-Warning { param($Message) $script:Warn.Add([string]$Message) }
function Set-Clipboard { param($Value) $script:Clip = [string]$Value }
function Read-Host { param($Prompt) if (-not $script:Answers.Count) { throw "Unexpected prompt: $Prompt" }; $script:Answers.Dequeue() }
function Test-PcMenuKeyboard { $false }

$script:Answers.Enqueue('C'); $script:Answers.Enqueue(''); $script:Answers.Enqueue('B')
Show-PcSqlSnippet $fix 'Windows > SQL Server Snippets > Users & Security'
$joined = $script:Out -join "`n"
Assert ($joined -match 'Type: MODIFICATION') 'Detail view shows the query type'
Assert ($joined -match 'Scope: Database') 'Detail view shows scope metadata'
Assert ($joined -match 'Permissions: ALTER ANY USER') 'Detail view shows permission metadata'
Assert ($joined -match 'Compatibility: SQL Server 2016-2025') 'Detail view shows compatibility metadata'
Assert ($joined -match 'Cost: Light') 'Detail view shows cost metadata'
Assert ($joined -match 'WARNING: This query modifies') 'Modification query shows a warning'
Assert ($joined -match 'ALTER USER \[YourUser\]') 'Generated SQL is displayed'
Assert ($joined -match '\[C\] Copy query to clipboard') 'Copy option is offered'
Assert ($script:Clip -match 'ALTER USER \[YourUser\]') 'Copy puts the generated SQL on the clipboard'
Assert ($script:Answers.Count -eq 0) 'All detail-view prompts were consumed'

# --- Parameter editing ---
$script:Out.Clear()
foreach ($answer in @('P', 'MyAppDb', '', 'applogin', 'C', '', 'B')) { $script:Answers.Enqueue($answer) }
Show-PcSqlSnippet $fix 'Windows > SQL Server Snippets > Users & Security'
$joined = $script:Out -join "`n"
Assert ($joined -match 'ALTER USER \[YourUser\]') 'Kept parameter keeps its default'
Assert ($joined -match 'USE \[MyAppDb\]') 'Edited parameter value is substituted'
Assert ($joined -match 'WITH LOGIN = \[applogin\]') 'Third parameter is substituted'
Assert ($script:Clip -match 'USE \[MyAppDb\]') 'Clipboard reflects edited parameters'

# --- SQL diagnostic correctness guards ---
$sqlRoot = Join-Path $PSScriptRoot '../win/sql'
$blocking = Get-Content -LiteralPath (Join-Path $sqlRoot 'performance/blocking-sessions.sql') -Raw
Assert ($blocking -notmatch 'JOIN\s+sys\.dm_exec_requests\s+AS\s+blocking') 'Blocking query does not require the blocker to have an active request'
Assert ($blocking -match 'blocking_sess\.open_transaction_count') 'Blocking query exposes sleeping blocker transaction state'
$tempdb = Get-Content -LiteralPath (Join-Path $sqlRoot 'troubleshooting/tempdb-usage.sql') -Raw
Assert ($tempdb -match 'alloc_page_count\s*-\s*user_objects_dealloc_page_count') 'TempDB query subtracts user-object deallocations'
Assert ($tempdb -match 'sys\.dm_db_task_space_usage') 'TempDB query includes active task allocations'
$missingIndexes = Get-Content -LiteralPath (Join-Path $sqlRoot 'performance/missing-indexes.sql') -Raw
Assert ($missingIndexes -match 'avg_total_user_cost\s*\*\s*migs\.avg_user_impact\s*\*') 'Missing-index ranking includes cumulative workload frequency'
$compatibility = Get-Content -LiteralPath (Join-Path $sqlRoot 'health/compatibility-levels.sql') -Raw
Assert ($compatibility -match "WHEN 170 THEN 'SQL Server 2025'") 'Compatibility snippet recognizes SQL Server 2025'

# --- Top-level category dispatch ---
$script:CalledCategory = $null
$script:MenuItems = $null
$script:MenuAnswers = New-Object 'Collections.Generic.Queue[string]'
function Start-PcSqlSnippetCategory { param([string]$CategoryId) $script:CalledCategory = $CategoryId }
function Read-PcCategoryMenu { param($Title, $Items, $State, $Description) $script:MenuItems = $Items; if ($script:MenuAnswers.Count) { $script:MenuAnswers.Dequeue() } else { 'B' } }
$script:MenuAnswers.Enqueue('2'); $script:MenuAnswers.Enqueue('B')
Start-PcSqlSnippetsMenu
Assert ($script:CalledCategory -eq 'health') 'Selecting category 2 opens Database Health'
Assert ($script:MenuItems.Count -eq 6) 'Top-level menu lists six categories'

# --- Toolkit integration (text assertions) ---
$toolkit = Get-Content (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1') -Raw
$module = Get-Content (Join-Path $PSScriptRoot '../win/modules/Sql-Snippets.ps1') -Raw
$embedded = ($toolkit -split '# BEGIN SQL SNIPPETS', 2)[1] -split '# END SQL SNIPPETS', 2
Assert ($embedded[0].Replace("`r`n", "`n").Trim() -eq $module.Replace("`r`n", "`n").Trim()) 'Embedded SQL snippets module matches source'
Assert ($toolkit -match "New-PcMenuItem '17' 'SQL Server Snippets'") 'Main menu exposes SQL Server Snippets as item 17'
Assert ($toolkit -match "'17'\s*\{\s*Start-PcSqlSnippetsMenu\s*\}") 'Main menu dispatches to the SQL snippets section'

# --- Version consistency ---
$version = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '../win/VERSION') -Raw).Trim()
Assert ($version -match '^\d+\.\d+\.\d+$') 'VERSION is a semantic version'
Assert ($toolkit -match ('# Random Toolkits \| Windows Toolkit ' + [regex]::Escape($version))) 'Toolkit header declares the version'
Assert ($toolkit -match ('\$script:PcToolkitVersion=' + "'" + [regex]::Escape($version) + "'")) 'Toolkit version variable matches VERSION'
$endpoint = Join-Path $PSScriptRoot '../win/index.html'
Assert ((Get-FileHash (Join-Path $PSScriptRoot '../win/Windows-Toolkit.ps1')).Hash -eq (Get-FileHash $endpoint).Hash) 'Generated endpoint matches the launcher byte-for-byte'

Write-Output "All SQL snippets checks passed on PowerShell $($PSVersionTable.PSVersion)."
