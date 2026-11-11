-- tempdb allocation by session, ordered by the largest consumers.
SELECT su.session_id                              AS SessionId,
       s.login_name                               AS LoginName,
       su.user_objects_alloc_page_count           AS UserObjectsAllocPages,
       su.user_objects_dealloc_page_count         AS UserObjectsDeallocPages,
       su.internal_objects_alloc_page_count       AS InternalObjectsAllocPages,
       su.internal_objects_dealloc_page_count     AS InternalObjectsDeallocPages,
       CAST((su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) * 8 / 1024.0 AS decimal(18,2)) AS AllocatedMB
FROM   sys.dm_db_session_space_usage AS su
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = su.session_id
WHERE  su.database_id = 2
ORDER  BY AllocatedMB DESC;
GO
