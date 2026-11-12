-- Expands blocking chains from each head blocker, including sleeping sessions.
WITH waits AS
(
    SELECT session_id,
           blocking_session_id,
           wait_type,
           wait_time,
           wait_resource,
           database_id
    FROM   sys.dm_exec_requests
    WHERE  blocking_session_id > 0
),
heads AS
(
    SELECT DISTINCT w.blocking_session_id AS HeadBlocker
    FROM   waits AS w
    WHERE  NOT EXISTS
           (
               SELECT 1
               FROM   waits AS parent
               WHERE  parent.session_id = w.blocking_session_id
           )
),
chain AS
(
    SELECT h.HeadBlocker,
           h.HeadBlocker AS SessionId,
           CAST(NULL AS smallint) AS BlockedBy,
           0 AS Depth,
           CAST('>' + CONVERT(varchar(11), h.HeadBlocker) + '>' AS varchar(max)) AS Visited
    FROM   heads AS h

    UNION ALL

    SELECT c.HeadBlocker,
           w.session_id,
           w.blocking_session_id,
           c.Depth + 1,
           CAST(c.Visited + CONVERT(varchar(11), w.session_id) + '>' AS varchar(max))
    FROM   chain AS c
           JOIN waits AS w
                ON w.blocking_session_id = c.SessionId
    WHERE  c.Visited NOT LIKE '%>' + CONVERT(varchar(11), w.session_id) + '>%'
)
SELECT c.HeadBlocker,
       c.Depth,
       c.SessionId,
       c.BlockedBy,
       s.status                   AS SessionStatus,
       s.open_transaction_count  AS OpenTransactions,
       s.login_name              AS LoginName,
       s.host_name               AS HostName,
       s.program_name            AS ProgramName,
       DB_NAME(w.database_id)    AS DatabaseName,
       w.wait_type               AS WaitType,
       w.wait_time               AS WaitMs,
       w.wait_resource           AS WaitResource,
       input_buffer.event_info   AS LastCommand
FROM   chain AS c
       LEFT JOIN waits AS w ON w.session_id = c.SessionId
       LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = c.SessionId
       OUTER APPLY sys.dm_exec_input_buffer(c.SessionId, NULL) AS input_buffer
ORDER  BY c.HeadBlocker, c.Depth, c.SessionId
OPTION (MAXRECURSION 100);
GO
