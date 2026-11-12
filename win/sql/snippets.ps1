# SQL Server snippet registry — source of truth for snippet metadata.
# SQL text lives in <Category>/<Id>.sql and is embedded by tests/Sync-SqlSnippets.ps1.
#
# Fields:
#   Id          unique lowercase-kebab identifier; must match the .sql filename.
#   Title       short display title.
#   Category    category id: users | health | performance | maintenance | connections | troubleshooting.
#   Description one-line purpose shown in menus and the detail view.
#   Type        'READ-ONLY' or 'MODIFICATION'.
#   Scope, Permissions, Compatibility, Cost operational context shown before copying.
#   Docs        optional Microsoft Learn URL.
#   SqlFile     path relative to win/sql/ (no leading slash).
#
# Parameters (optional; declare them only when the SQL uses {{Name}} tokens):
#   @{ Name='Database'; Default='YourDatabase'; Kind='Identifier' }
#   Kind: 'Identifier' (default, rendered as [value]), 'Literal' (N'value'),
#         'Integer', 'Decimal', or 'Enum'. Numeric kinds support Min/Max and
#         Enum requires AllowedValues. Every token and declaration must match.
$registry = @(
    # Users & Security
    [pscustomobject]@{ Id='orphaned-users';       Title='Detect orphaned database users';          Category='users';           Description='Lists database users whose SID has no matching server login.'; Type='READ-ONLY';   Docs='https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters/troubleshoot-orphaned-users-sql-server'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='users/orphaned-users.sql' }
    [pscustomobject]@{ Id='fix-orphaned-users';   Title='Fix orphaned database user';               Category='users';           Description='Remaps an existing database user to a server login.'; Type='MODIFICATION';  Docs='https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-user-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'},@{Name='User';Default='YourUser';Kind='Identifier'},@{Name='Login';Default='YourLogin';Kind='Identifier'}); SqlFile='users/fix-orphaned-users.sql' }
    [pscustomobject]@{ Id='db-users-logins';      Title='List database users and associated logins'; Category='users';           Description='Database users joined to their matching server login by SID.'; Type='READ-ONLY';   Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='users/db-users-logins.sql' }
    [pscustomobject]@{ Id='db-permissions';       Title='List explicit database permissions';       Category='users';           Description='Explicit database permissions granted or denied to principals; fixed-role permissions are not included.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-permissions-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='users/db-permissions.sql' }
    [pscustomobject]@{ Id='server-roles-members'; Title='List server roles and members';            Category='users';           Description='Fixed and user-defined server roles and their members (server-scoped).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-server-role-members-transact-sql'; Parameters=@(); SqlFile='users/server-roles-members.sql' }

    # Database Health
    [pscustomobject]@{ Id='database-status-sizes'; Title='Database status and sizes';               Category='health';          Description='Status, recovery model, compatibility level, and size for every database.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql'; Parameters=@(); SqlFile='health/database-status-sizes.sql' }
    [pscustomobject]@{ Id='integrity-check';       Title='Database integrity check';                Category='health';          Description='Full allocation and consistency check (DBCC CHECKDB). Resource intensive.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Literal'}); SqlFile='health/integrity-check.sql' }
    [pscustomobject]@{ Id='txn-log-usage';        Title='Transaction log usage';                   Category='health';          Description='Transaction log file size and used space for the current database.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='health/txn-log-usage.sql' }
    [pscustomobject]@{ Id='compatibility-levels';  Title='Database compatibility levels';           Category='health';          Description='Compatibility level of every database with its friendly SQL Server name.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level'; Parameters=@(); SqlFile='health/compatibility-levels.sql' }
    [pscustomobject]@{ Id='recovery-models';       Title='Recovery models';                         Category='health';          Description='Recovery model and current log reuse wait for every database.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server'; Parameters=@(); SqlFile='health/recovery-models.sql' }
    [pscustomobject]@{ Id='database-free-space';   Title='Database file and volume free space';     Category='health';          Description='File allocation, unallocated space, growth settings, and hosting-volume capacity for one database.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-volume-stats-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='health/database-free-space.sql' }

    # Performance
    [pscustomobject]@{ Id='currently-executing';   Title='Currently executing queries';             Category='performance';     Description='All requests currently executing on the instance (server-scoped).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'; Parameters=@(); SqlFile='performance/currently-executing.sql' }
    [pscustomobject]@{ Id='blocking-sessions';     Title='Blocking sessions';                       Category='performance';     Description='Requests blocked by another session, with both sides logins and hosts.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'; Parameters=@(); SqlFile='performance/blocking-sessions.sql' }
    [pscustomobject]@{ Id='blocking-chain';        Title='Blocking chains and head blockers';       Category='performance';     Description='Expands blocking chains from each head blocker, including sleeping sessions.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/understand-resolve-blocking'; Parameters=@(); SqlFile='performance/blocking-chain.sql' }
    [pscustomobject]@{ Id='long-running-queries';  Title='Long-running queries';                    Category='performance';     Description='Queries running longer than the configured threshold (default 5 minutes).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql'; Parameters=@(@{Name='ThresholdMinutes';Default='5';Kind='Integer';Min='1';Max='10080'}); SqlFile='performance/long-running-queries.sql' }
    [pscustomobject]@{ Id='index-fragmentation';   Title='Index fragmentation';                     Category='performance';     Description='Index fragmentation above 5% with at least 100 pages (LIMITED scan).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='performance/index-fragmentation.sql' }
    [pscustomobject]@{ Id='missing-indexes';       Title='Missing index recommendations';           Category='performance';     Description='Missing index suggestions ranked by estimated query-cost impact.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql'; Parameters=@(@{Name='Database';Default='YourDatabase';Kind='Identifier'}); SqlFile='performance/missing-indexes.sql' }

    # Maintenance
    [pscustomobject]@{ Id='backup-history';        Title='Backup history';                          Category='maintenance';     Description='Backup history for the last N days (default 7) from msdb.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql'; Parameters=@(@{Name='Days';Default='7';Kind='Integer';Min='1';Max='3650'}); SqlFile='maintenance/backup-history.sql' }
    [pscustomobject]@{ Id='last-successful-backups'; Title='Last successful backups';               Category='maintenance';     Description='Most recent successful full, differential, and log backup per database.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql'; Parameters=@(); SqlFile='maintenance/last-successful-backups.sql' }
    [pscustomobject]@{ Id='agent-job-failures';    Title='SQL Server Agent job failures';           Category='maintenance';     Description='Recent SQL Server Agent job failures from msdb history.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql'; Parameters=@(); SqlFile='maintenance/agent-job-failures.sql' }
    [pscustomobject]@{ Id='file-growth-config';    Title='Database file growth configuration';       Category='maintenance';     Description='Per-file size, growth setting, and max size for every database.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql'; Parameters=@(); SqlFile='maintenance/file-growth-config.sql' }
    [pscustomobject]@{ Id='backup-compliance';     Title='Backup threshold compliance';              Category='maintenance';     Description='Flags online databases whose latest full, differential, or log backup exceeds configurable thresholds.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-overview-sql-server'; Parameters=@(@{Name='FullDays';Default='7';Kind='Integer';Min='1';Max='3650'},@{Name='DifferentialDays';Default='1';Kind='Integer';Min='1';Max='3650'},@{Name='LogMinutes';Default='60';Kind='Integer';Min='1';Max='525600'}); SqlFile='maintenance/backup-compliance.sql' }

    # Connections & Sessions
    [pscustomobject]@{ Id='active-connections';    Title='Active connections';                      Category='connections';     Description='Active user connections to the instance (server-scoped).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'; Parameters=@(); SqlFile='connections/active-connections.sql' }
    [pscustomobject]@{ Id='sessions-by-database';  Title='Sessions grouped by database';            Category='connections';     Description='Count of sessions per database, split by running and sleeping state.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'; Parameters=@(); SqlFile='connections/sessions-by-database.sql' }
    [pscustomobject]@{ Id='sleeping-sessions';     Title='Sleeping sessions';                       Category='connections';     Description='User sessions that are sleeping, ordered by oldest activity first.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql'; Parameters=@(); SqlFile='connections/sleeping-sessions.sql' }
    [pscustomobject]@{ Id='open-transactions';     Title='Open transactions';                       Category='connections';     Description='Open transactions, their owning session, age, and type (server-scoped).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql'; Parameters=@(); SqlFile='connections/open-transactions.sql' }
    [pscustomobject]@{ Id='long-running-transactions'; Title='Long-running open transactions';       Category='connections';     Description='Open user transactions older than a configurable threshold, with session and last-command context.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql'; Parameters=@(@{Name='ThresholdMinutes';Default='5';Kind='Integer';Min='1';Max='10080'}); SqlFile='connections/long-running-transactions.sql' }

    # Troubleshooting
    [pscustomobject]@{ Id='version-edition';       Title='SQL Server version and edition';          Category='troubleshooting'; Description='SQL Server version, edition, and high-availability properties.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql'; Parameters=@(); SqlFile='troubleshooting/version-edition.sql' }
    [pscustomobject]@{ Id='server-configuration';  Title='Server configuration';                    Category='troubleshooting'; Description='All sp_configure settings with their current, minimum, and maximum values.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql'; Parameters=@(); SqlFile='troubleshooting/server-configuration.sql' }
    [pscustomobject]@{ Id='wait-stats';            Title='Wait statistics';                         Category='troubleshooting'; Description='Cumulative wait statistics since the instance started (benign waits excluded).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql'; Parameters=@(); SqlFile='troubleshooting/wait-stats.sql' }
    [pscustomobject]@{ Id='tempdb-usage';          Title='TempDB usage';                            Category='troubleshooting'; Description='Net completed-task and active-task tempdb allocation by session, ordered by the largest consumers.'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-session-space-usage-transact-sql'; Parameters=@(); SqlFile='troubleshooting/tempdb-usage.sql' }
    [pscustomobject]@{ Id='recovery-pending';      Title='Databases in RECOVERY_PENDING state';     Category='troubleshooting'; Description='Databases stuck in RECOVERY_PENDING state (state = 3).'; Type='READ-ONLY'; Docs='https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql'; Parameters=@(); SqlFile='troubleshooting/recovery-pending.sql' }
)

$serverState = 'VIEW SERVER STATE (SQL Server 2022+: VIEW SERVER PERFORMANCE STATE)'
$databaseState = 'VIEW DATABASE STATE or sufficient database metadata visibility'
$msdbRead = 'Read access to msdb backup and SQL Agent history'
$metadata = @{
    'orphaned-users'          = @('Database', 'Database metadata visibility', 'SQL Server 2016-2025', 'Light')
    'fix-orphaned-users'      = @('Database', 'ALTER ANY USER plus access to the target login', 'SQL Server 2016-2025', 'Light')
    'db-users-logins'         = @('Database and server', 'Database metadata visibility and login metadata visibility', 'SQL Server 2016-2025', 'Light')
    'db-permissions'          = @('Database', 'VIEW SECURITY DEFINITION (SQL Server 2022+) or sufficient metadata visibility', 'SQL Server 2016-2025', 'Light')
    'server-roles-members'    = @('Server', 'Server principal metadata visibility', 'SQL Server 2016-2025', 'Light')
    'database-status-sizes'   = @('Server', 'Database and file metadata visibility', 'SQL Server 2016-2025', 'Light')
    'integrity-check'         = @('Database', 'Permissions required by DBCC CHECKDB', 'SQL Server 2016-2025', 'Heavy')
    'txn-log-usage'           = @('Database', $databaseState, 'SQL Server 2016-2025', 'Light')
    'compatibility-levels'    = @('Server', 'Database metadata visibility', 'SQL Server 2016-2025', 'Light')
    'recovery-models'         = @('Server', 'Database metadata visibility', 'SQL Server 2016-2025', 'Light')
    'database-free-space'     = @('Database and host volume', $serverState, 'SQL Server 2016-2025', 'Light')
    'currently-executing'     = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'blocking-sessions'       = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'blocking-chain'          = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'long-running-queries'    = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'index-fragmentation'     = @('Database', $databaseState, 'SQL Server 2016-2025', 'Moderate')
    'missing-indexes'         = @('Database', $serverState, 'SQL Server 2016-2025', 'Light')
    'backup-history'          = @('Server / msdb', $msdbRead, 'SQL Server 2016-2025', 'Light')
    'last-successful-backups' = @('Server / msdb', $msdbRead, 'SQL Server 2016-2025', 'Light')
    'agent-job-failures'      = @('Server / msdb', $msdbRead, 'SQL Server 2016-2025', 'Light')
    'file-growth-config'      = @('Server', 'Database and file metadata visibility', 'SQL Server 2016-2025', 'Light')
    'backup-compliance'       = @('Server / msdb', $msdbRead, 'SQL Server 2016-2025', 'Light')
    'active-connections'      = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'sessions-by-database'    = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'sleeping-sessions'       = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'open-transactions'       = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'long-running-transactions' = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'version-edition'         = @('Server', 'Public server metadata access', 'SQL Server 2016-2025', 'Light')
    'server-configuration'    = @('Server', 'Server configuration metadata visibility', 'SQL Server 2016-2025', 'Light')
    'wait-stats'              = @('Server', $serverState, 'SQL Server 2016-2025', 'Light')
    'tempdb-usage'            = @('Server / tempdb', $serverState, 'SQL Server 2016-2025', 'Light')
    'recovery-pending'        = @('Server', 'Database metadata visibility', 'SQL Server 2016-2025', 'Light')
}

foreach ($snippet in $registry) {
    if (-not $snippet.Scope -or -not $snippet.Permissions -or -not $snippet.Compatibility -or -not $snippet.Cost) {
        $values = $metadata[[string]$snippet.Id]
        if ($null -eq $values) { throw "Missing operational metadata for SQL snippet '$($snippet.Id)'." }
        $snippet | Add-Member -NotePropertyName Scope -NotePropertyValue $values[0]
        $snippet | Add-Member -NotePropertyName Permissions -NotePropertyValue $values[1]
        $snippet | Add-Member -NotePropertyName Compatibility -NotePropertyValue $values[2]
        $snippet | Add-Member -NotePropertyName Cost -NotePropertyValue $values[3]
    }
    $snippet
}
