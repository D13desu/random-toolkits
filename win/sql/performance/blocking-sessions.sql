-- Requests blocked by another session, including sleeping head blockers.
SELECT blocked.session_id                  AS BlockedSession,
       blocked.blocking_session_id         AS BlockingSession,
       blocked.wait_type                   AS WaitType,
       blocked.wait_time                   AS WaitMs,
       blocked.wait_resource               AS WaitResource,
       DB_NAME(blocked.database_id)        AS DatabaseName,
       blocked_sess.login_name             AS BlockedLogin,
       blocking_sess.login_name            AS BlockingLogin,
       blocked_sess.host_name              AS BlockedHost,
       blocking_sess.host_name             AS BlockingHost,
       blocking_sess.status                AS BlockingSessionStatus,
       blocking_sess.open_transaction_count AS BlockingOpenTransactions,
       blocking_sess.last_request_end_time AS BlockingLastRequestEnd,
       input_buffer.event_info             AS BlockingLastCommand
FROM   sys.dm_exec_requests AS blocked
       JOIN sys.dm_exec_sessions AS blocked_sess
            ON blocked_sess.session_id = blocked.session_id
       JOIN sys.dm_exec_sessions AS blocking_sess
            ON blocking_sess.session_id = blocked.blocking_session_id
       OUTER APPLY sys.dm_exec_input_buffer(blocked.blocking_session_id, NULL) AS input_buffer
WHERE  blocked.blocking_session_id > 0
ORDER  BY blocked.wait_time DESC;
GO
