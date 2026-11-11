-- Count of sessions per database, split by running and sleeping state.
SELECT DB_NAME(s.database_id)    AS DatabaseName,
       COUNT(*)                  AS SessionCount,
       SUM(CASE WHEN s.status = 'running'  THEN 1 ELSE 0 END) AS Running,
       SUM(CASE WHEN s.status = 'sleeping' THEN 1 ELSE 0 END) AS Sleeping
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
GROUP  BY s.database_id
ORDER  BY SessionCount DESC;
GO
