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
