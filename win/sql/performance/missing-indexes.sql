-- Missing index suggestions ranked by estimated query-cost impact.
USE {{Database}};
GO

SELECT migs.avg_total_user_cost                       AS AvgQueryCost,
       migs.avg_user_impact                           AS AvgImpactPercent,
       migs.user_seeks + migs.user_scans              AS Reads,
       CONVERT(decimal(28,1), migs.avg_total_user_cost * migs.avg_user_impact *
               (migs.user_seeks + migs.user_scans))   AS ImprovementMeasure,
       migs.last_user_seek                             AS LastUserSeek,
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
ORDER  BY migs.avg_total_user_cost * migs.avg_user_impact *
          (migs.user_seeks + migs.user_scans) DESC;
GO
