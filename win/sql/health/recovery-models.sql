-- Recovery model and current log reuse wait for every database.
SELECT d.name                AS DatabaseName,
       d.recovery_model_desc AS RecoveryModel,
       d.log_reuse_wait_desc AS LogReuseWait
FROM   sys.databases AS d
ORDER  BY d.name;
GO
