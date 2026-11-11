-- Open transactions, their owning session, age, and type (server-scoped).
SELECT at.transaction_id                           AS TransactionId,
       st.session_id                               AS SessionId,
       s.login_name                                AS LoginName,
       DB_NAME(dt.database_id)                     AS DatabaseName,
       at.name                                     AS TransactionName,
       at.transaction_begin_time                   AS BeginTime,
       DATEDIFF(SECOND, at.transaction_begin_time, GETDATE()) AS AgeSeconds,
       CASE at.transaction_type
            WHEN 1 THEN 'Read/Write'
            WHEN 2 THEN 'Read-Only'
            WHEN 3 THEN 'System'
            WHEN 4 THEN 'Distributed'
            ELSE CAST(at.transaction_type AS varchar(10))
       END                                         AS TransactionType
FROM   sys.dm_tran_active_transactions AS at
       JOIN sys.dm_tran_session_transactions AS st
            ON st.transaction_id = at.transaction_id
       JOIN sys.dm_exec_sessions AS s
            ON s.session_id = st.session_id
       LEFT JOIN sys.dm_tran_database_transactions AS dt
            ON dt.transaction_id = at.transaction_id
ORDER  BY at.transaction_begin_time ASC;
GO
