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
