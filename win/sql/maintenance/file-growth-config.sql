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
