-- Active user connections to the instance (server-scoped).
SELECT s.session_id                AS SessionId,
       s.login_name                AS LoginName,
       s.host_name                 AS HostName,
       s.program_name              AS ProgramName,
       DB_NAME(s.database_id)      AS DatabaseName,
       s.status                    AS Status,
       s.login_time                AS LoginTime,
       s.last_request_end_time     AS LastActivity
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
  AND  s.session_id <> @@SPID
ORDER  BY s.last_request_end_time DESC;
GO
