-- User sessions that are sleeping, ordered by oldest activity first.
SELECT s.session_id                       AS SessionId,
       s.login_name                       AS LoginName,
       s.host_name                        AS HostName,
       s.program_name                     AS ProgramName,
       DB_NAME(s.database_id)             AS DatabaseName,
       s.last_request_end_time            AS LastActivity,
       DATEDIFF(MINUTE, s.last_request_end_time, GETDATE()) AS IdleMinutes
FROM   sys.dm_exec_sessions AS s
WHERE  s.is_user_process = 1
  AND  s.status = 'sleeping'
  AND  s.session_id <> @@SPID
ORDER  BY s.last_request_end_time ASC;
GO
