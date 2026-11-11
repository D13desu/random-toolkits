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
