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
