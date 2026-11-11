-- Recent SQL Server Agent job failures from msdb history.
-- run_date is YYYYMMDD and run_time is HHMMSS integers.
SELECT j.name                        AS JobName,
       j.enabled                     AS JobEnabled,
       h.run_date                    AS RunDate,
       h.run_time                    AS RunTime,
       h.run_status                  AS RunStatus,
       h.message                     AS Message
FROM   msdb.dbo.sysjobs AS j
       JOIN msdb.dbo.sysjobhistory AS h
            ON h.job_id = j.job_id
WHERE  h.run_status = 0
  AND  h.step_id = 0
ORDER  BY h.run_date DESC, h.run_time DESC;
GO
