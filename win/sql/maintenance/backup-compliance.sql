-- Backup recency compared with configurable operational thresholds.
-- Thresholds are reference values; align them with the organization's RPO policy.
WITH latest AS
(
    SELECT database_name,
           MAX(CASE WHEN type = 'D' AND is_copy_only = 0 THEN backup_finish_date END) AS LastFull,
           MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDifferential,
           MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLog
    FROM   msdb.dbo.backupset
    GROUP  BY database_name
)
SELECT d.name                                          AS DatabaseName,
       d.recovery_model_desc                           AS RecoveryModel,
       b.LastFull,
       CASE WHEN b.LastFull >= DATEADD(DAY, -{{FullDays}}, GETDATE())
            THEN 'OK' ELSE 'OVERDUE' END               AS FullBackupStatus,
       b.LastDifferential,
       CASE WHEN b.LastDifferential >= DATEADD(DAY, -{{DifferentialDays}}, GETDATE())
            THEN 'OK' ELSE 'OVERDUE' END               AS DifferentialBackupStatus,
       b.LastLog,
       CASE WHEN d.recovery_model_desc = 'SIMPLE' THEN 'N/A (SIMPLE)'
            WHEN b.LastLog >= DATEADD(MINUTE, -{{LogMinutes}}, GETDATE()) THEN 'OK'
            ELSE 'OVERDUE' END                         AS LogBackupStatus
FROM   sys.databases AS d
       LEFT JOIN latest AS b ON b.database_name = d.name
WHERE  d.database_id <> 2
  AND  d.state = 0
ORDER  BY d.name;
GO
