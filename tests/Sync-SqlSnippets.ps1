$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$launcher = Join-Path $repoRoot 'win/Windows-Toolkit.ps1'
$endpointPath = Join-Path $repoRoot 'win/index.html'
$modulePath = Join-Path $repoRoot 'win/modules/Sql-Snippets.ps1'
$registryPath = Join-Path $repoRoot 'win/sql/snippets.ps1'
$sqlRoot = Join-Path $repoRoot 'win/sql'

$dataStart = '# BEGIN SQL SNIPPET DATA'
$dataEnd = '# END SQL SNIPPET DATA'
$moduleStart = '# BEGIN SQL SNIPPETS'
$moduleEnd = '# END SQL SNIPPETS'

$knownCategories = @('users', 'health', 'performance', 'maintenance', 'connections', 'troubleshooting')

function ConvertTo-PcSqlSingleQuotedLiteral {
    # Single-quoted PowerShell string literal (doubles embedded quotes).
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { $Value = '' }
    return "'" + ($Value -replace "'", "''") + "'"
}

# --- Load and validate the registry ---
$snippets = @(. $registryPath)
if (-not $snippets -or $snippets.Count -eq 0) { throw 'SQL snippet registry is empty.' }

$ids = @{}
foreach ($snippet in $snippets) {
    $id = [string]$snippet.Id
    if ([string]::IsNullOrWhiteSpace($id)) { throw 'SQL snippet has an empty Id.' }
    if ($id -notmatch '^[a-z0-9-]+$') { throw "Invalid snippet Id (lowercase-kebab expected): $id" }
    if ($ids.ContainsKey($id)) { throw "Duplicate snippet Id: $id" }
    $ids[$id] = $true

    if ([string]::IsNullOrWhiteSpace([string]$snippet.Title)) { throw "Snippet $id has no Title." }
    if ([string]::IsNullOrWhiteSpace([string]$snippet.Description)) { throw "Snippet $id has no Description." }
    foreach ($field in @('Scope', 'Permissions', 'Compatibility', 'Cost')) {
        if ([string]::IsNullOrWhiteSpace([string]$snippet.$field)) { throw "Snippet $id has no $field metadata." }
    }
    if ([string]$snippet.Cost -notin @('Light', 'Moderate', 'Heavy')) { throw "Snippet $id has invalid Cost '$($snippet.Cost)'." }
    $category = [string]$snippet.Category
    if ($category -notin $knownCategories) { throw "Snippet $id has unknown Category '$category'." }
    $type = [string]$snippet.Type
    if ($type -notin @('READ-ONLY', 'MODIFICATION')) { throw "Snippet $id has invalid Type '$type'." }

    $sqlFile = [string]$snippet.SqlFile
    if ([string]::IsNullOrWhiteSpace($sqlFile)) { throw "Snippet $id has no SqlFile." }
    $expectedSqlFile = "$category/$id.sql"
    if ($sqlFile.Replace('\', '/') -cne $expectedSqlFile) { throw "Snippet $id SqlFile must be '$expectedSqlFile'." }
    $sqlPath = Join-Path $sqlRoot $sqlFile
    $resolvedSqlPath = [IO.Path]::GetFullPath($sqlPath)
    if (-not $resolvedSqlPath.StartsWith(([IO.Path]::GetFullPath($sqlRoot) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Snippet $id SQL file escapes win/sql: $sqlFile"
    }
    if (-not [IO.File]::Exists($sqlPath)) { throw "Snippet $id references missing SQL file: $sqlFile" }

    $parameters = @($snippet.Parameters)
    $paramNames = @{}
    foreach ($parameter in $parameters) {
        $name = [string]$parameter.Name
        if ([string]::IsNullOrWhiteSpace($name)) { throw "Snippet $id has a parameter with no Name." }
        if ($paramNames.ContainsKey($name)) { throw "Snippet $id has duplicate parameter '$name'." }
        $paramNames[$name] = $true
        $kind = if ($parameter.Kind) { [string]$parameter.Kind } else { 'Identifier' }
        if ($kind -notin @('Identifier', 'Literal', 'Integer', 'Decimal', 'Enum')) { throw "Snippet $id parameter '$name' has invalid Kind '$kind'." }
        if ($kind -eq 'Enum' -and @($parameter.AllowedValues).Count -eq 0) { throw "Snippet $id enum parameter '$name' has no AllowedValues." }
    }

    $sql = [IO.File]::ReadAllText($sqlPath)
    $tokenSet = @{}
    foreach ($match in [regex]::Matches($sql, '\{\{([A-Za-z][A-Za-z0-9]*)\}\}')) {
        $tokenSet[[string]$match.Groups[1].Value] = $true
    }
    foreach ($token in $tokenSet.Keys) {
        if (-not $paramNames.ContainsKey($token)) { throw "Snippet $id uses undeclared parameter token '{{$token}}'." }
    }
    foreach ($paramName in $paramNames.Keys) {
        if (-not $tokenSet.ContainsKey($paramName)) { throw "Snippet $id declares parameter '$paramName' that does not appear in the SQL." }
    }
    $unresolved = [regex]::Matches($sql, '\{\{.*?\}\}')
    foreach ($token in $unresolved) {
        if ($token.Value -notmatch '^\{\{[A-Za-z][A-Za-z0-9]*\}\}$') { throw "Snippet $id has malformed parameter token '$($token.Value)'." }
    }
    $withoutValidTokens = [regex]::Replace($sql, '\{\{[A-Za-z][A-Za-z0-9]*\}\}', '')
    if ($withoutValidTokens.Contains('{{') -or $withoutValidTokens.Contains('}}')) { throw "Snippet $id has an incomplete or malformed parameter token." }
}

$registeredFiles = @($snippets | ForEach-Object { ([string]$_.SqlFile).Replace('\', '/') })
$orphanedFiles = @(Get-ChildItem -LiteralPath $sqlRoot -Recurse -Filter '*.sql' -File | ForEach-Object {
    $_.FullName.Substring(([IO.Path]::GetFullPath($sqlRoot)).Length + 1).Replace('\', '/')
} | Where-Object { $_ -notin $registeredFiles })
if ($orphanedFiles.Count) { throw "Unregistered SQL files: $($orphanedFiles -join ', ')" }

# --- Generate the data section ---
$dataLines = New-Object 'Collections.Generic.List[string]'
$dataLines.Add('function Get-PcSqlSnippetRegistry {')
$dataLines.Add('    return @(')
for ($i = 0; $i -lt $snippets.Count; $i++) {
    $snippet = $snippets[$i]
    $dataLines.Add('        [pscustomobject]@{')
    $dataLines.Add('            Id=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Id)))
    $dataLines.Add('            Title=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Title)))
    $dataLines.Add('            Category=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Category)))
    $dataLines.Add('            Description=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Description)))
    $dataLines.Add('            Type=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Type)))
    $dataLines.Add('            Scope=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Scope)))
    $dataLines.Add('            Permissions=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Permissions)))
    $dataLines.Add('            Compatibility=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Compatibility)))
    $dataLines.Add('            Cost=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$snippet.Cost)))
    $docs = if ($snippet.Docs) { [string]$snippet.Docs } else { '' }
    $dataLines.Add('            Docs=' + (ConvertTo-PcSqlSingleQuotedLiteral $docs))
    $parameterStrings = @()
    foreach ($parameter in @($snippet.Parameters)) {
        $name = [string]$parameter.Name
        $default = if ($null -eq $parameter.Default) { '' } else { [string]$parameter.Default }
        $kind = if ($parameter.Kind) { [string]$parameter.Kind } else { 'Identifier' }
        $parts = @(
            'Name=' + (ConvertTo-PcSqlSingleQuotedLiteral $name)
            'Default=' + (ConvertTo-PcSqlSingleQuotedLiteral $default)
            'Kind=' + (ConvertTo-PcSqlSingleQuotedLiteral $kind)
        )
        if ($null -ne $parameter.Min) { $parts += 'Min=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$parameter.Min)) }
        if ($null -ne $parameter.Max) { $parts += 'Max=' + (ConvertTo-PcSqlSingleQuotedLiteral ([string]$parameter.Max)) }
        if ($null -ne $parameter.AllowedValues -and @($parameter.AllowedValues).Count -gt 0) {
            $allowed = @($parameter.AllowedValues | ForEach-Object { ConvertTo-PcSqlSingleQuotedLiteral ([string]$_) })
            $parts += 'AllowedValues=@(' + ($allowed -join ',') + ')'
        }
        $parameterStrings += '[pscustomobject]@{' + ($parts -join ';') + '}'
    }
    $dataLines.Add('            Parameters=@(' + ($parameterStrings -join ',') + ')')
    $dataLines.Add("            Sql=@'")
    foreach ($line in ([IO.File]::ReadAllText((Join-Path $sqlRoot ([string]$snippet.SqlFile))) -split "`r?`n")) {
        $dataLines.Add($line)
    }
    $dataLines.Add("'@")
    if ($i -lt $snippets.Count - 1) { $dataLines.Add('        },') } else { $dataLines.Add('        }') }
}
$dataLines.Add('    )')
$dataLines.Add('}')
$dataText = $dataLines -join "`n"

# --- Regenerate the module's data section ---
$module = [IO.File]::ReadAllText($modulePath)
$a = $module.IndexOf($dataStart)
$b = $module.IndexOf($dataEnd)
if ($a -lt 0 -or $b -le $a) { throw 'SQL snippet data markers missing from Sql-Snippets.ps1.' }
$newModule = $module.Substring(0, $a) + $dataStart + "`r`n" + $dataText + "`r`n" + $module.Substring($b)

$tokens = $null
$errors = $null
$null = [Management.Automation.Language.Parser]::ParseInput($newModule, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "Generated SQL snippets module has PowerShell parse errors:`n$($errors -join "`n")" }
[IO.File]::WriteAllText($modulePath, $newModule, [Text.UTF8Encoding]::new($false))

# --- Inject the module into the launcher ---
$source = [IO.File]::ReadAllText($launcher)
$sa = $source.IndexOf($moduleStart)
$sb = $source.IndexOf($moduleEnd)
if ($sa -lt 0 -or $sb -le $sa) { throw 'SQL snippets markers missing from Windows-Toolkit.ps1.' }
$source = $source.Substring(0, $sa) + $moduleStart + "`r`n" + $newModule.TrimEnd() + "`r`n" + $source.Substring($sb)

$tokens = $null
$errors = $null
$null = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "Generated Windows toolkit has PowerShell parse errors:`n$($errors -join "`n")" }

[IO.File]::WriteAllText($launcher, $source, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $launcher -Destination $endpointPath

Write-Output "SQL snippets synchronized ($($snippets.Count) snippets)."
