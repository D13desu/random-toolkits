-- Open user transactions older than the configured threshold.
SELECT st.session_id                                  AS SessionId,
       s.login_name                                   AS LoginName,
       s.host_name                                    AS HostName,
       s.program_name                                 AS ProgramName,
       s.status                                       AS SessionStatus,
       s.open_transaction_count                       AS SessionOpenTransactions,
       at.transaction_id                              AS TransactionId,
       at.name                                        AS TransactionName,
       at.transaction_begin_time                      AS BeginTime,
       DATEDIFF(MINUTE, at.transaction_begin_time, GETDATE()) AS AgeMinutes,
       r.status                                       AS RequestStatus,
       r.command                                      AS RequestCommand,
       input_buffer.event_info                        AS LastCommand
FROM   sys.dm_tran_active_transactions AS at
       JOIN sys.dm_tran_session_transactions AS st
            ON st.transaction_id = at.transaction_id
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = st.session_id
       LEFT JOIN sys.dm_exec_requests AS r
            ON r.session_id = st.session_id
       OUTER APPLY sys.dm_exec_input_buffer(st.session_id, NULL) AS input_buffer
WHERE  s.is_user_process = 1
  AND  at.transaction_begin_time <= DATEADD(MINUTE, -{{ThresholdMinutes}}, GETDATE())
ORDER  BY at.transaction_begin_time ASC;
GO
