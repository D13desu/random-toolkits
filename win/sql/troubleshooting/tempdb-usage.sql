-- Net tempdb allocation by session. Session counters cover completed tasks;
-- task counters add allocations belonging to requests that are still active.
WITH completed AS
(
    SELECT session_id,
           (user_objects_alloc_page_count - user_objects_dealloc_page_count) +
           (internal_objects_alloc_page_count - internal_objects_dealloc_page_count) AS NetPages
    FROM   sys.dm_db_session_space_usage
    WHERE  database_id = 2
),
active AS
(
    SELECT session_id,
           SUM((user_objects_alloc_page_count - user_objects_dealloc_page_count) +
               (internal_objects_alloc_page_count - internal_objects_dealloc_page_count)) AS NetPages
    FROM   sys.dm_db_task_space_usage
    WHERE  database_id = 2
    GROUP  BY session_id
)
SELECT s.session_id                                      AS SessionId,
       s.login_name                                      AS LoginName,
       s.host_name                                       AS HostName,
       s.program_name                                    AS ProgramName,
       COALESCE(c.NetPages, 0)                           AS CompletedTaskNetPages,
       COALESCE(a.NetPages, 0)                           AS ActiveTaskNetPages,
       CAST((COALESCE(c.NetPages, 0) + COALESCE(a.NetPages, 0)) * 8 / 1024.0 AS decimal(18,2)) AS NetAllocatedMB
FROM   sys.dm_exec_sessions AS s
       LEFT JOIN completed AS c ON c.session_id = s.session_id
       LEFT JOIN active AS a ON a.session_id = s.session_id
WHERE  COALESCE(c.NetPages, 0) + COALESCE(a.NetPages, 0) <> 0
ORDER  BY NetAllocatedMB DESC;
GO
