# SQL Server Snippets — reusable snippet browser.
#
# Renders the snippet registry returned by Get-PcSqlSnippetRegistry (generated
# from win/sql/* by tests/Sync-SqlSnippets.ps1). It generates, displays, and
# copies T-SQL text only: it never connects to a server, never executes SQL,
# and never requests credentials.
#
# The escaping helpers below are the T-SQL-specific extension point. To add
# another engine later, supply a dialect with its own identifier/literal rules
# and reuse the menu, parameter, and clipboard machinery unchanged.

function ConvertTo-PcSqlIdentifier {
    # [name] with embedded ] escaped as ]].
    param([AllowEmptyString()][string]$Value)
    '[' + ($Value -replace '\]', ']]') + ']'
}

function ConvertTo-PcSqlLiteral {
    # N'value' with embedded single quotes doubled; NULL for $null.
    param($Value)
    if ($null -eq $Value) { return 'NULL' }
    "N'" + (([string]$Value) -replace "'", "''") + "'"
}

function ConvertTo-PcSqlParameterValue {
    param([object]$Parameter, [AllowNull()][string]$Value)
    if ($null -eq $Value) { $Value = '' }
    $kind = if ($Parameter.Kind) { [string]$Parameter.Kind } else { 'Identifier' }
    switch ($kind) {
        'Literal'    { return ConvertTo-PcSqlLiteral $Value }
        'Raw'        { return $Value }
        default      { return ConvertTo-PcSqlIdentifier $Value }
    }
}

function Expand-PcSqlSnippet {
    # Replaces every {{Name}} token with the (escaped) parameter value.
    param([object]$Snippet, [hashtable]$Values)
    $sql = [string]$Snippet.Sql
    foreach ($parameter in @($Snippet.Parameters)) {
        $name = [string]$parameter.Name
        $value = if ($Values -and $Values.ContainsKey($name)) { $Values[$name] } else { $parameter.Default }
        $sql = $sql.Replace('{{' + $name + '}}', (ConvertTo-PcSqlParameterValue $parameter ([string]$value)))
    }
    return $sql
}

function Get-PcSqlSnippetDefaults {
    param([object]$Snippet)
    $values = @{}
    foreach ($parameter in @($Snippet.Parameters)) {
        $name = [string]$parameter.Name
        $values[$name] = if ($null -eq $parameter.Default) { '' } else { [string]$parameter.Default }
    }
    return $values
}

function Read-PcSqlSnippetParameters {
    # Prompt for each parameter; an empty answer keeps the current value.
    param([object]$Snippet, [hashtable]$Values)
    foreach ($parameter in @($Snippet.Parameters)) {
        $name = [string]$parameter.Name
        $current = if ($Values -and $Values.ContainsKey($name)) { $Values[$name] } else { $parameter.Default }
        if ($null -eq $current) { $current = '' }
        $answer = Read-Host ("  {0} [{1}] (Enter: keep)" -f $name, $current)
        if ($null -ne $answer -and $answer.Trim() -ne '') { $Values[$name] = $answer.Trim() }
    }
    return $Values
}

function Get-PcSqlSnippet {
    param([string]$Id)
    Get-PcSqlSnippetRegistry | Where-Object { [string]$_.Id -eq $Id } | Select-Object -First 1
}

function Get-PcSqlSnippetCategories {
    # Ordered category list for the SQL snippets menu.
    @(
        [pscustomobject]@{ Id='users';           Title='Users & Security';       Description='Logins, users, roles, and permissions.' }
        [pscustomobject]@{ Id='health';          Title='Database Health';        Description='Status, integrity, logs, and recovery configuration.' }
        [pscustomobject]@{ Id='performance';     Title='Performance';            Description='Running queries, blocking, and index health.' }
        [pscustomobject]@{ Id='maintenance';     Title='Maintenance';            Description='Backups, Agent jobs, and file growth.' }
        [pscustomobject]@{ Id='connections';     Title='Connections & Sessions'; Description='Active connections, sessions, and transactions.' }
        [pscustomobject]@{ Id='troubleshooting'; Title='Troubleshooting';        Description='Version, configuration, waits, and tempdb.' }
    )
}

function New-PcSqlSnippetMenuItem {
    param([object]$Snippet)
    $typeColor = if ($Snippet.Type -eq 'MODIFICATION') { 'Yellow' } else { 'Green' }
    [pscustomobject]@{
        Id         = [string]$Snippet.Id
        Label      = [string]$Snippet.Title
        Detail     = [string]$Snippet.Description
        SearchText = [string]$Snippet.Description
        Data       = $Snippet
        LabelParts = @(
            [pscustomobject]@{ Text = [string]$Snippet.Title; Color = 'White' }
            [pscustomobject]@{ Text = '  [' + [string]$Snippet.Type + ']'; Color = $typeColor }
        )
    }
}

function Show-PcSqlSnippet {
    param([object]$Snippet, [string]$Breadcrumb)
    $values = Get-PcSqlSnippetDefaults $Snippet
    $notice = ''
    $parameters = @($Snippet.Parameters)
    $hasParams = $parameters.Count -gt 0
    while ($true) {
        $sql = Expand-PcSqlSnippet $Snippet $values
        Clear-PcMenuScreen
        Write-Host (Get-PcMenuHeading $Breadcrumb) -ForegroundColor Cyan
        Write-Host ''
        Write-Host ([string]$Snippet.Title).ToUpperInvariant() -ForegroundColor Cyan
        Write-Host ''
        $typeColor = if ($Snippet.Type -eq 'MODIFICATION') { 'Yellow' } else { 'Green' }
        Write-Host ('Type: ' + $Snippet.Type) -ForegroundColor $typeColor
        if ($Snippet.Type -eq 'MODIFICATION') {
            Write-Host 'WARNING: This query modifies data or metadata. Review it carefully and run it only against the intended target.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host 'Description:' -ForegroundColor Gray
        Write-Host ([string]$Snippet.Description)
        if ($Snippet.Docs) {
            Write-Host ('Reference: ' + $Snippet.Docs) -ForegroundColor DarkGray
        }
        if ($hasParams) {
            Write-Host ''
            Write-Host 'Parameters:' -ForegroundColor Gray
            $maxName = ($parameters | ForEach-Object { ([string]$_.Name).Length } | Measure-Object -Maximum).Maximum
            foreach ($parameter in $parameters) {
                $name = [string]$parameter.Name
                $value = if ($values.ContainsKey($name)) { [string]$values[$name] } else { '' }
                $displayValue = ConvertTo-PcSqlParameterValue $parameter $value
                Write-Host ('  ' + $name.PadRight($maxName) + ': ' + $displayValue)
            }
        }
        Write-Host ''
        Write-Host 'Generated SQL:' -ForegroundColor Gray
        Write-Host ('-' * 48) -ForegroundColor DarkGray
        foreach ($line in ($sql -split "`r?`n")) { Write-Host $line }
        Write-Host ('-' * 48) -ForegroundColor DarkGray
        Write-Host 'This toolkit never connects to or executes against SQL Server. Review permissions and target before running.' -ForegroundColor DarkGray
        Write-Host ''
        if ($notice) { Write-Warning $notice; $notice = '' }
        $prompt = if ($hasParams) { '[C] Copy query to clipboard | [P] Edit parameters | [B] Back' } else { '[C] Copy query to clipboard | [B] Back' }
        Write-Host $prompt
        $answer = Read-Host 'Choice'
        if ($null -eq $answer) { return }
        $choice = $answer.Trim().ToUpperInvariant()
        if ($choice -eq 'C') {
            try { Set-Clipboard -Value $sql; Write-Host 'Query copied to clipboard.' -ForegroundColor Green }
            catch { Write-Warning ('Could not copy to clipboard: ' + $_.Exception.Message) }
            $null = Read-Host 'Press Enter to continue'
            continue
        }
        if ($hasParams -and $choice -eq 'P') {
            $values = Read-PcSqlSnippetParameters $Snippet $values
            continue
        }
        if ($choice -in @('B', '')) { return }
        $notice = if ($hasParams) { 'Choose C, P, or B.' } else { 'Choose C or B.' }
    }
}

function Start-PcSqlSnippetCategory {
    param([string]$CategoryId)
    $category = Get-PcSqlSnippetCategories | Where-Object Id -eq $CategoryId | Select-Object -First 1
    if (-not $category) { return }
    $snippets = @(Get-PcSqlSnippetRegistry | Where-Object { [string]$_.Category -eq $CategoryId })
    $state = @{}
    $breadcrumb = 'Windows > SQL Server Snippets > ' + $category.Title
    while ($true) {
        $menu = @(foreach ($snippet in $snippets) { New-PcSqlSnippetMenuItem $snippet })
        $choice = Show-PcMenu -Title $breadcrumb -Items $menu -State $state -Description $category.Description -EmptyMessage 'No snippets in this category.'
        if ($choice.Action -eq 'Back') { return }
        if ($choice.Action -eq 'Select') { Show-PcSqlSnippet $choice.Item.Data $breadcrumb }
    }
}

function Start-PcSqlSnippetsMenu {
    $state = @{}
    while ($true) {
        $categories = @(Get-PcSqlSnippetCategories)
        $menu = @(for ($i = 0; $i -lt $categories.Count; $i++) {
            New-PcMenuItem ([string]($i + 1)) $categories[$i].Title 'Menu' $categories[$i].Description
        })
        $answer = Read-PcCategoryMenu 'Windows > SQL Server Snippets' $menu $state 'Copy-only T-SQL snippets by category. Nothing is executed and no connection is made; many queries need VIEW SERVER STATE or db_owner.'
        if ($null -eq $answer -or $answer -in @('0', 'B', 'Back')) { return }
        $index = [int]$answer - 1
        if ($index -ge 0 -and $index -lt $categories.Count) {
            Start-PcSqlSnippetCategory $categories[$index].Id
        }
    }
}

# BEGIN SQL SNIPPET DATA
function Get-PcSqlSnippetRegistry {
    return @(
        [pscustomobject]@{
            Id='orphaned-users'
            Title='Detect orphaned database users'
            Category='users'
            Description='Lists database users whose SID has no matching server login.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Lists database users whose SID has no matching server login (orphaned users).
USE {{Database}};
GO

SELECT dp.name                          AS OrphanedUser,
       dp.type_desc                     AS UserType,
       CONVERT(varchar(85), dp.sid, 1)  AS UserSid,
       dp.create_date                   AS Created
FROM   sys.database_principals AS dp
WHERE  dp.type IN ('S', 'U')
  AND  dp.sid IS NOT NULL
  AND  dp.principal_id > 4
  AND  NOT EXISTS
       (
           SELECT 1
           FROM   sys.server_principals AS sp
           WHERE  sp.sid = dp.sid
       )
ORDER  BY dp.name;
GO

'@
        },
        [pscustomobject]@{
            Id='fix-orphaned-users'
            Title='Fix orphaned database user'
            Category='users'
            Description='Remaps an existing database user to a server login.'
            Type='MODIFICATION'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-user-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'},[pscustomobject]@{Name='User';Default='YourUser';Kind='Identifier'},[pscustomobject]@{Name='Login';Default='YourLogin';Kind='Identifier'})
            Sql=@'
-- Remaps an existing database user to an existing server login.
-- Verify that the login and user are the intended pair before running.
USE {{Database}};
GO

ALTER USER {{User}}
WITH LOGIN = {{Login}};
GO

'@
        },
        [pscustomobject]@{
            Id='db-users-logins'
            Title='List database users and associated logins'
            Category='users'
            Description='Database users joined to their matching server login by SID.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Database users joined to their matching server login by SID.
USE {{Database}};
GO

SELECT dp.name                                AS DatabaseUser,
       dp.type_desc                           AS UserType,
       ISNULL(sp.name, '(no matching login)') AS ServerLogin,
       sp.type_desc                           AS LoginType,
       sp.is_disabled                         AS LoginDisabled
FROM   sys.database_principals AS dp
       LEFT JOIN sys.server_principals AS sp
              ON sp.sid = dp.sid
WHERE  dp.type IN ('S', 'U')
  AND  dp.principal_id > 4
ORDER  BY dp.name;
GO

'@
        },
        [pscustomobject]@{
            Id='db-permissions'
            Title='List database permissions'
            Category='users'
            Description='Effective database permissions granted to principals.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Effective database permissions granted to principals.
USE {{Database}};
GO

SELECT pr.name                AS Principal,
       pr.type_desc           AS PrincipalType,
       perm.state_desc        AS State,
       perm.permission_name   AS Permission,
       perm.class_desc        AS Class,
       ISNULL(OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id), '(database)') AS Securable
FROM   sys.database_permissions AS perm
       JOIN sys.database_principals AS pr
            ON pr.principal_id = perm.grantee_principal_id
ORDER  BY pr.name, perm.permission_name;
GO

'@
        },
        [pscustomobject]@{
            Id='server-roles-members'
            Title='List server roles and members'
            Category='users'
            Description='Fixed and user-defined server roles and their members (server-scoped).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-role-members-transact-sql'
            Parameters=@()
            Sql=@'
-- Fixed and user-defined server roles and their members (server-scoped).
SELECT r.name                 AS ServerRole,
       m.name                 AS Member,
       m.type_desc            AS MemberType,
       m.is_disabled          AS MemberDisabled
FROM   sys.server_role_members AS rm
       JOIN sys.server_principals AS r
            ON r.principal_id = rm.role_principal_id
       JOIN sys.server_principals AS m
            ON m.principal_id = rm.member_principal_id
ORDER  BY r.name, m.name;
GO

'@
        },
        [pscustomobject]@{
            Id='database-status-sizes'
            Title='Database status and sizes'
            Category='health'
            Description='Status, recovery model, compatibility level, and size for every database.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql'
            Parameters=@()
            Sql=@'
-- Status, recovery model, compatibility level, and size for every database.
SELECT d.name          AS DatabaseName,
       d.state_desc    AS State,
       d.recovery_model_desc AS RecoveryModel,
       d.compatibility_level AS CompatibilityLevel,
       CAST(SUM(CASE WHEN mf.type = 0 THEN mf.size ELSE 0 END) * 8 / 1024.0 AS decimal(18,2)) AS DataSizeMB,
       CAST(SUM(CASE WHEN mf.type = 1 THEN mf.size ELSE 0 END) * 8 / 1024.0 AS decimal(18,2)) AS LogSizeMB
FROM   sys.databases AS d
       LEFT JOIN sys.master_files AS mf
              ON mf.database_id = d.database_id
GROUP  BY d.name, d.state_desc, d.recovery_model_desc, d.compatibility_level
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='integrity-check'
            Title='Database integrity check'
            Category='health'
            Description='Full allocation and consistency check (DBCC CHECKDB). Resource intensive.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Literal'})
            Sql=@'
-- Full allocation and consistency check. Resource intensive and can run for
-- a long time on large databases. Read-only: no REPAIR option is supplied.
DBCC CHECKDB ({{Database}})
WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO

'@
        },
        [pscustomobject]@{
            Id='txn-log-usage'
            Title='Transaction log usage'
            Category='health'
            Description='Transaction log file size and used space for the current database.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Transaction log file size and used space for the current database.
USE {{Database}};
GO

SELECT name                                            AS LogFileName,
       CAST(size * 8 / 1024.0 AS decimal(18,2))        AS SizeMB,
       CAST(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024.0 AS decimal(18,2)) AS UsedMB,
       CAST(100.0 * FILEPROPERTY(name, 'SpaceUsed') / NULLIF(size, 0) AS decimal(5,2)) AS UsedPercent
FROM   sys.database_files
WHERE  type = 1;
GO

'@
        },
        [pscustomobject]@{
            Id='compatibility-levels'
            Title='Database compatibility levels'
            Category='health'
            Description='Compatibility level of every database with its friendly SQL Server name.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level'
            Parameters=@()
            Sql=@'
-- Compatibility level of every database with its friendly SQL Server name.
SELECT name                       AS DatabaseName,
       compatibility_level        AS CompatibilityLevel,
       CASE compatibility_level
            WHEN 100 THEN 'SQL Server 2008 / 2008 R2'
            WHEN 110 THEN 'SQL Server 2012'
            WHEN 120 THEN 'SQL Server 2014'
            WHEN 130 THEN 'SQL Server 2016'
            WHEN 140 THEN 'SQL Server 2017'
            WHEN 150 THEN 'SQL Server 2019'
            WHEN 160 THEN 'SQL Server 2022'
            ELSE 'Unknown / custom'
       END                        AS CompatibilityLevelName
FROM   sys.databases
ORDER  BY name;
GO

'@
        },
        [pscustomobject]@{
            Id='recovery-models'
            Title='Recovery models'
            Category='health'
            Description='Recovery model and current log reuse wait for every database.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server'
            Parameters=@()
            Sql=@'
-- Recovery model and current log reuse wait for every database.
SELECT d.name                AS DatabaseName,
       d.recovery_model_desc AS RecoveryModel,
       d.log_reuse_wait_desc AS LogReuseWait
FROM   sys.databases AS d
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='currently-executing'
            Title='Currently executing queries'
            Category='performance'
            Description='All requests currently executing on the instance (server-scoped).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'
            Parameters=@()
            Sql=@'
-- All requests currently executing on the instance (server-scoped).
SELECT r.session_id                                    AS SessionId,
       r.status                                        AS Status,
       r.command                                       AS Command,
       r.blocking_session_id                           AS BlockingSession,
       DB_NAME(r.database_id)                          AS DatabaseName,
       r.cpu_time                                      AS CpuMs,
       r.total_elapsed_time                            AS ElapsedMs,
       s.login_name                                    AS LoginName,
       s.host_name                                     AS HostName,
       s.program_name                                  AS ProgramName,
       SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                 ((CASE r.statement_end_offset
                       WHEN -1 THEN DATALENGTH(t.text)
                       ELSE r.statement_end_offset
                   END - r.statement_start_offset) / 2) + 1) AS QueryText
FROM   sys.dm_exec_requests AS r
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = r.session_id
       CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE  r.session_id <> @@SPID
ORDER  BY r.total_elapsed_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='blocking-sessions'
            Title='Blocking sessions'
            Category='performance'
            Description='Requests blocked by another session, with both sides logins and hosts.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'
            Parameters=@()
            Sql=@'
-- Requests blocked by another session, with both sides' logins and hosts.
SELECT blocked.session_id                  AS BlockedSession,
       blocking.session_id                 AS BlockingSession,
       blocked.wait_type                   AS WaitType,
       blocked.wait_time                   AS WaitMs,
       blocked.wait_resource               AS WaitResource,
       DB_NAME(blocked.database_id)        AS DatabaseName,
       blocked_sess.login_name             AS BlockedLogin,
       blocking_sess.login_name            AS BlockingLogin,
       blocked_sess.host_name              AS BlockedHost,
       blocking_sess.host_name             AS BlockingHost
FROM   sys.dm_exec_requests AS blocked
       JOIN sys.dm_exec_requests AS blocking
            ON blocking.session_id = blocked.blocking_session_id
       JOIN sys.dm_exec_sessions AS blocked_sess
            ON blocked_sess.session_id = blocked.session_id
       JOIN sys.dm_exec_sessions AS blocking_sess
            ON blocking_sess.session_id = blocking.session_id
ORDER  BY blocked.wait_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='long-running-queries'
            Title='Long-running queries'
            Category='performance'
            Description='Queries running longer than the configured threshold (default 5 minutes).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'
            Parameters=@([pscustomobject]@{Name='ThresholdMinutes';Default='5';Kind='Raw'})
            Sql=@'
-- Queries running longer than the configured threshold (default 5 minutes).
SELECT r.session_id                   AS SessionId,
       s.login_name                   AS LoginName,
       DB_NAME(r.database_id)         AS DatabaseName,
       r.total_elapsed_time           AS ElapsedMs,
       r.cpu_time                     AS CpuMs,
       r.logical_reads                AS LogicalReads,
       r.status                       AS Status,
       r.command                      AS Command,
       SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                 ((CASE r.statement_end_offset
                       WHEN -1 THEN DATALENGTH(t.text)
                       ELSE r.statement_end_offset
                   END - r.statement_start_offset) / 2) + 1) AS QueryText
FROM   sys.dm_exec_requests AS r
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = r.session_id
       CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE  r.session_id <> @@SPID
  AND  r.total_elapsed_time > {{ThresholdMinutes}} * 60000
ORDER  BY r.total_elapsed_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='index-fragmentation'
            Title='Index fragmentation'
            Category='performance'
            Description='Index fragmentation above 5% with at least 100 pages (LIMITED scan).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Index fragmentation above 5% with at least 100 pages (LIMITED scan).
USE {{Database}};
GO

SELECT OBJECT_NAME(ips.object_id)               AS TableName,
       i.name                                   AS IndexName,
       ips.index_type_desc                      AS IndexType,
       ips.avg_fragmentation_in_percent         AS FragmentationPercent,
       ips.page_count                           AS PageCount
FROM   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
       JOIN sys.indexes AS i
            ON i.object_id = ips.object_id
           AND i.index_id = ips.index_id
WHERE  ips.avg_fragmentation_in_percent > 5
  AND  ips.page_count > 100
ORDER  BY ips.avg_fragmentation_in_percent DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='missing-indexes'
            Title='Missing index recommendations'
            Category='performance'
            Description='Missing index suggestions ranked by estimated query-cost impact.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql'
            Parameters=@([pscustomobject]@{Name='Database';Default='YourDatabase';Kind='Identifier'})
            Sql=@'
-- Missing index suggestions ranked by estimated query-cost impact.
USE {{Database}};
GO

SELECT migs.avg_total_user_cost                       AS AvgQueryCost,
       migs.avg_user_impact                           AS AvgImpactPercent,
       migs.user_seeks + migs.user_scans              AS Reads,
       mid.statement                                  AS [Table],
       mid.equality_columns                           AS EqualityColumns,
       mid.inequality_columns                         AS InequalityColumns,
       mid.included_columns                           AS IncludedColumns
FROM   sys.dm_db_missing_index_details AS mid
       JOIN sys.dm_db_missing_index_groups AS mig
            ON mig.index_handle = mid.index_handle
       JOIN sys.dm_db_missing_index_group_stats AS migs
            ON migs.group_handle = mig.index_group_handle
WHERE  mid.database_id = DB_ID()
ORDER  BY migs.avg_total_user_cost * migs.avg_user_impact DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='backup-history'
            Title='Backup history'
            Category='maintenance'
            Description='Backup history for the last N days (default 7) from msdb.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql'
            Parameters=@([pscustomobject]@{Name='Days';Default='7';Kind='Raw'})
            Sql=@'
-- Backup history for the last N days (default 7) from msdb.
SELECT s.database_name                                  AS DatabaseName,
       s.backup_start_date                              AS StartTime,
       s.backup_finish_date                             AS FinishTime,
       CASE s.type
            WHEN 'D' THEN 'Full'
            WHEN 'I' THEN 'Differential'
            WHEN 'L' THEN 'Log'
            WHEN 'F' THEN 'File / Filegroup'
            ELSE s.type
       END                                              AS BackupType,
       CAST(s.backup_size / 1048576.0 AS decimal(18,2)) AS SizeMB,
       s.user_name                                      AS UserName,
       mf.physical_device_name                          AS Destination
FROM   msdb.dbo.backupset AS s
       JOIN msdb.dbo.backupmediafamily AS mf
            ON mf.media_set_id = s.media_set_id
WHERE  s.backup_finish_date >= DATEADD(DAY, -{{Days}}, GETDATE())
ORDER  BY s.backup_finish_date DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='last-successful-backups'
            Title='Last successful backups'
            Category='maintenance'
            Description='Most recent successful full, differential, and log backup per database.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql'
            Parameters=@()
            Sql=@'
-- Most recent successful full, differential, and log backup per database.
SELECT d.name          AS DatabaseName,
       d.recovery_model_desc AS RecoveryModel,
       MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END) AS LastFullBackup,
       MAX(CASE WHEN b.type = 'I' THEN b.backup_finish_date END) AS LastDifferentialBackup,
       MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END) AS LastLogBackup
FROM   sys.databases AS d
       LEFT JOIN msdb.dbo.backupset AS b
            ON b.database_name = d.name
GROUP  BY d.name, d.recovery_model_desc
ORDER  BY d.name;
GO

'@
        },
        [pscustomobject]@{
            Id='agent-job-failures'
            Title='SQL Server Agent job failures'
            Category='maintenance'
            Description='Recent SQL Server Agent job failures from msdb history.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql'
            Parameters=@()
            Sql=@'
-- Recent SQL Server Agent job failures from msdb history.
-- run_date is YYYYMMDD and run_time is HHMMSS integers.
SELECT j.name                        AS JobName,
       j.enabled                     AS JobEnabled,
       h.run_date                    AS RunDate,
       h.run_time                    AS RunTime,
       h.run_status                  AS RunStatus,
       h.message                     AS Message
FROM   msdb.dbo.sysjobs AS j
       JOIN msdb.dbo.sysjobhistory AS h
            ON h.job_id = j.job_id
WHERE  h.run_status = 0
  AND  h.step_id = 0
ORDER  BY h.run_date DESC, h.run_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='file-growth-config'
            Title='Database file growth configuration'
            Category='maintenance'
            Description='Per-file size, growth setting, and max size for every database.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql'
            Parameters=@()
            Sql=@'
-- Per-file size, growth setting, and max size for every database.
SELECT d.name                                        AS DatabaseName,
       mf.name                                       AS FileName,
       mf.type_desc                                  AS FileType,
       CAST(mf.size * 8 / 1024.0 AS decimal(18,2))   AS SizeMB,
       CASE WHEN mf.is_percent_growth = 1
            THEN CAST(mf.growth AS varchar(10)) + '%'
            ELSE CAST(mf.growth * 8 / 1024 AS varchar(20)) + ' MB'
       END                                           AS GrowthSetting,
       CASE WHEN mf.max_size = -1
            THEN 'Unlimited'
            ELSE CAST(mf.max_size * 8 / 1024 AS varchar(20)) + ' MB'
       END                                           AS MaxSizeMB
FROM   sys.master_files AS mf
       JOIN sys.databases AS d
            ON d.database_id = mf.database_id
ORDER  BY d.name, mf.name;
GO

'@
        },
        [pscustomobject]@{
            Id='active-connections'
            Title='Active connections'
            Category='connections'
            Description='Active user connections to the instance (server-scoped).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'
            Parameters=@()
            Sql=@'
-- Active user connections to the instance (server-scoped).
SELECT s.session_id                AS SessionId,
       s.login_name                AS LoginName,
       s.host_name                 AS HostName,
       s.program_name              AS ProgramName,
       DB_NAME(s.database_id)      AS DatabaseName,
       s.status                    AS Status,
       s.login_time                AS LoginTime,
       s.last_request_end_time     AS LastActivity
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
  AND  s.session_id <> @@SPID
ORDER  BY s.last_request_end_time DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='sessions-by-database'
            Title='Sessions grouped by database'
            Category='connections'
            Description='Count of sessions per database, split by running and sleeping state.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'
            Parameters=@()
            Sql=@'
-- Count of sessions per database, split by running and sleeping state.
SELECT DB_NAME(s.database_id)    AS DatabaseName,
       COUNT(*)                  AS SessionCount,
       SUM(CASE WHEN s.status = 'running'  THEN 1 ELSE 0 END) AS Running,
       SUM(CASE WHEN s.status = 'sleeping' THEN 1 ELSE 0 END) AS Sleeping
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
GROUP  BY s.database_id
ORDER  BY SessionCount DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='sleeping-sessions'
            Title='Sleeping sessions'
            Category='connections'
            Description='User sessions that are sleeping, ordered by oldest activity first.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'
            Parameters=@()
            Sql=@'
-- User sessions that are sleeping, ordered by oldest activity first.
SELECT s.session_id                       AS SessionId,
       s.login_name                       AS LoginName,
       s.host_name                        AS HostName,
       s.program_name                     AS ProgramName,
       DB_NAME(s.database_id)             AS DatabaseName,
       s.last_request_end_time            AS LastActivity,
       DATEDIFF(MINUTE, s.last_request_end_time, GETDATE()) AS IdleMinutes
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
  AND  s.status = 'sleeping'
  AND  s.session_id <> @@SPID
ORDER  BY s.last_request_end_time ASC;
GO

'@
        },
        [pscustomobject]@{
            Id='open-transactions'
            Title='Open transactions'
            Category='connections'
            Description='Open transactions, their owning session, age, and type (server-scoped).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql'
            Parameters=@()
            Sql=@'
-- Open transactions, their owning session, age, and type (server-scoped).
SELECT at.transaction_id                           AS TransactionId,
       st.session_id                               AS SessionId,
       s.login_name                                AS LoginName,
       DB_NAME(dt.database_id)                     AS DatabaseName,
       at.name                                     AS TransactionName,
       at.transaction_begin_time                   AS BeginTime,
       DATEDIFF(SECOND, at.transaction_begin_time, GETDATE()) AS AgeSeconds,
       CASE at.transaction_type
            WHEN 1 THEN 'Read/Write'
            WHEN 2 THEN 'Read-Only'
            WHEN 3 THEN 'System'
            WHEN 4 THEN 'Distributed'
            ELSE CAST(at.transaction_type AS varchar(10))
       END                                         AS TransactionType
FROM   sys.dm_tran_active_transactions AS at
       JOIN sys.dm_tran_session_transactions AS st
            ON st.transaction_id = at.transaction_id
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = st.session_id
       LEFT JOIN sys.dm_tran_database_transactions AS dt
            ON dt.transaction_id = at.transaction_id
ORDER  BY at.transaction_begin_time ASC;
GO

'@
        },
        [pscustomobject]@{
            Id='version-edition'
            Title='SQL Server version and edition'
            Category='troubleshooting'
            Description='SQL Server version, edition, and high-availability properties.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql'
            Parameters=@()
            Sql=@'
-- SQL Server version, edition, and high-availability properties.
SELECT SERVERPROPERTY('ServerName')              AS ServerName,
       SERVERPROPERTY('InstanceName')            AS InstanceName,
       SERVERPROPERTY('ProductVersion')          AS ProductVersion,
       SERVERPROPERTY('ProductLevel')            AS ProductLevel,
       SERVERPROPERTY('ProductUpdateLevel')      AS ProductUpdateLevel,
       SERVERPROPERTY('ProductBuildType')        AS ProductBuildType,
       SERVERPROPERTY('Edition')                 AS Edition,
       SERVERPROPERTY('EngineEdition')           AS EngineEdition,
       SERVERPROPERTY('IsClustered')             AS IsClustered,
       SERVERPROPERTY('IsHadrEnabled')           AS IsHadrEnabled;
GO

'@
        },
        [pscustomobject]@{
            Id='server-configuration'
            Title='Server configuration'
            Category='troubleshooting'
            Description='All sp_configure settings with their current, minimum, and maximum values.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql'
            Parameters=@()
            Sql=@'
-- All sp_configure settings with their current, minimum, and maximum values.
SELECT name                AS ConfigurationName,
       value_in_use        AS ValueInUse,
       minimum             AS Minimum,
       maximum             AS Maximum,
       description         AS Description,
       is_dynamic          AS IsDynamic,
       is_advanced         AS IsAdvanced
FROM   sys.configurations
ORDER  BY name;
GO

'@
        },
        [pscustomobject]@{
            Id='wait-stats'
            Title='Wait statistics'
            Category='troubleshooting'
            Description='Cumulative wait statistics since the instance started (benign waits excluded).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql'
            Parameters=@()
            Sql=@'
-- Cumulative wait statistics since the instance started (benign waits excluded).
SELECT wait_type                                          AS WaitType,
       waiting_tasks_count                                AS WaitingTasks,
       wait_time_ms                                       AS WaitTimeMs,
       max_wait_time_ms                                   AS MaxWaitTimeMs,
       signal_wait_time_ms                                AS SignalWaitTimeMs,
       CAST(100.0 * wait_time_ms / NULLIF(SUM(wait_time_ms) OVER (), 0) AS decimal(5,2)) AS PercentOfWaits
FROM   sys.dm_os_wait_stats
WHERE  wait_type NOT IN (
           'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP',
           'BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE','CHKPT',
           'CLR_AUTO_EVENT','CLR_MANUAL_EVENT','CLR_SEMAPHORE','DBMIRROR_DBM_EVENT',
           'DBMIRROR_EVENTS_QUEUE','DBMIRROR_WORKER_QUEUE','DBMIRRORING_CMD',
           'DIRTY_PAGE_POLL','DISPATCHER_QUEUE_SEMAPHORE','EXECSYNC','FSAGENT',
           'FT_IFTS_SCHEDULER_IDLE_WAIT','FT_IFTSHC_MUTEX','HADR_CLUSAPI_CALL',
           'HADR_FILESTREAM_IOMGR_IOCOMPLETION','HADR_LOGCAPTURE_WAIT',
           'HADR_NOTIFICATION_DEQUEUE','HADR_TIMER_TASK','HADR_WORK_QUEUE',
           'KSOURCE_WAKEUP','LAZYWRITER_SLEEP','LOGMGR_QUEUE','MEMORY_ALLOCATION_EXT',
           'ONDEMAND_TASK_QUEUE','PREEMPTIVE_OS_LIBRARYOPS','PREEMPTIVE_OS_COMOPS',
           'PREEMPTIVE_OS_CRYPTOPS','PREEMPTIVE_OS_PIPEOPS',
           'PREEMPTIVE_OS_AUTHENTICATIONOPS','PREEMPTIVE_OS_GENERICOPS',
           'PREEMPTIVE_OS_VERIFYTRUST','PREEMPTIVE_OS_FILEOPS',
           'PREEMPTIVE_OS_DEVICEOPS','PREEMPTIVE_OS_QUERYREGISTRY',
           'PREEMPTIVE_OS_WRITEFILE','REQUEST_FOR_DEADLOCK_SEARCH','RESOURCE_QUEUE',
           'SERVER_IDLE_CHECK','SLEEP_BPOOL_FLUSH','SLEEP_DBSTARTUP',
           'SLEEP_DCOMSTARTUP','SLEEP_MASTERMDREADY','SLEEP_MASTERUPGRADED',
           'SLEEP_MSDBSTARTUP','SLEEP_SYSTEMTASK','SLEEP_TASK',
           'SLEEP_TEMPDBSTARTUP','SP_SERVER_DIAGNOSTICS_SLEEP',
           'SQLTRACE_BUFFER_FLUSH','SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
           'SQLTRACE_WAIT_ENTRIES','WAIT_FOR_RESULTS','WAITFOR',
           'WAITFOR_TASKSHUTDOWN','WAIT_XTP_RECOVERY','WAIT_XTP_HOST_WAIT',
           'WAIT_XTP_OFFLINE_CKPT_NEW_LOG','WAIT_XTP_CKPT_CLOSE',
           'XE_DISPATCHER_JOIN','XE_DISPATCHER_WAIT','XE_TIMER_EVENT'
       )
ORDER  BY wait_time_ms DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='tempdb-usage'
            Title='TempDB usage'
            Category='troubleshooting'
            Description='tempdb allocation by session, ordered by the largest consumers.'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-session-space-usage-transact-sql'
            Parameters=@()
            Sql=@'
-- tempdb allocation by session, ordered by the largest consumers.
SELECT su.session_id                              AS SessionId,
       s.login_name                               AS LoginName,
       su.user_objects_alloc_page_count           AS UserObjectsAllocPages,
       su.user_objects_dealloc_page_count         AS UserObjectsDeallocPages,
       su.internal_objects_alloc_page_count       AS InternalObjectsAllocPages,
       su.internal_objects_dealloc_page_count     AS InternalObjectsDeallocPages,
       CAST((su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) * 8 / 1024.0 AS decimal(18,2)) AS AllocatedMB
FROM   sys.dm_db_session_space_usage AS su
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = su.session_id
WHERE  su.database_id = 2
ORDER  BY AllocatedMB DESC;
GO

'@
        },
        [pscustomobject]@{
            Id='recovery-pending'
            Title='Databases in RECOVERY_PENDING state'
            Category='troubleshooting'
            Description='Databases stuck in RECOVERY_PENDING state (state = 3).'
            Type='READ-ONLY'
            Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql'
            Parameters=@()
            Sql=@'
-- Databases stuck in RECOVERY_PENDING state (state = 3).
SELECT name                       AS DatabaseName,
       state_desc                 AS State,
       recovery_model_desc        AS RecoveryModel,
       is_in_standby              AS IsInStandby
FROM   sys.databases
WHERE  state = 3
ORDER  BY name;
GO

'@
        }
    )
}
# END SQL SNIPPET DATA
