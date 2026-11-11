-- Requests blocked by another session, with both sides' logins and hosts.
SELECT blocked.session_id                  AS BlockedSession,
       blocking.session_id                 AS BlockingSession,
       blocked.wait_type                   AS WaitType,
       blocked.wait_time                   AS WaitMs,
       blocked.wait_resource               AS WaitResource,
       DB_NAME(blocked.database_id)        AS DatabaseName,
       blocked_sess.login_name             AS BlockedLogin,
       blocking_sess.login_name            AS BlockingLogin,
       blocked_sess.host_name              AS BlockedHost,
       blocking_sess.host_name             AS BlockingHost
FROM   sys.dm_exec_requests AS blocked
       JOIN sys.dm_exec_requests AS blocking
            ON blocking.session_id = blocked.blocking_session_id
       JOIN sys.dm_exec_sessions AS blocked_sess
            ON blocked_sess.session_id = blocked.session_id
       JOIN sys.dm_exec_sessions AS blocking_sess
            ON blocking_sess.session_id = blocking.session_id
ORDER  BY blocked.wait_time DESC;
GO
