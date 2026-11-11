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
