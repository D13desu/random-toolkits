-- File allocation, unallocated space, growth settings, and volume capacity.
USE {{Database}};
GO

SELECT DB_NAME()                                        AS DatabaseName,
       df.file_id                                       AS FileId,
       df.name                                          AS LogicalFileName,
       df.type_desc                                     AS FileType,
       df.physical_name                                 AS PhysicalName,
       CAST(df.size * 8 / 1024.0 AS decimal(18,2))      AS FileSizeMB,
       CAST(FILEPROPERTY(df.name, 'SpaceUsed') * 8 / 1024.0 AS decimal(18,2)) AS UsedMB,
       CAST((df.size - FILEPROPERTY(df.name, 'SpaceUsed')) * 8 / 1024.0 AS decimal(18,2)) AS UnallocatedMB,
       CASE WHEN df.is_percent_growth = 1
            THEN CONVERT(varchar(20), df.growth) + '%'
            ELSE CONVERT(varchar(20), df.growth * 8 / 1024) + ' MB'
       END                                              AS GrowthSetting,
       vs.volume_mount_point                            AS VolumeMountPoint,
       CAST(vs.total_bytes / 1048576.0 AS decimal(18,2)) AS VolumeSizeMB,
       CAST(vs.available_bytes / 1048576.0 AS decimal(18,2)) AS VolumeFreeMB
FROM   sys.database_files AS df
       CROSS APPLY sys.dm_os_volume_stats(DB_ID(), df.file_id) AS vs
ORDER  BY df.type, df.file_id;
GO
