-- All requests currently executing on the instance (server-scoped).
SELECT r.session_id                                    AS SessionId,
       r.status                                        AS Status,
       r.command                                       AS Command,
       r.blocking_session_id                           AS BlockingSession,
       DB_NAME(r.database_id)                          AS DatabaseName,
       r.cpu_time                                      AS CpuMs,
       r.total_elapsed_time                            AS ElapsedMs,
       s.login_name                                    AS LoginName,
       s.host_name                                     AS HostName,
       s.program_name                                  AS ProgramName,
       SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
                 ((CASE r.statement_end_offset
                       WHEN -1 THEN DATALENGTH(t.text)
                       ELSE r.statement_end_offset
                   END - r.statement_start_offset) / 2) + 1) AS QueryText
FROM   sys.dm_exec_requests AS r
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = r.session_id
       CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE  r.session_id <> @@SPID
ORDER  BY r.total_elapsed_time DESC;
GO
