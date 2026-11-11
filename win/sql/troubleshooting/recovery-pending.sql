-- Databases stuck in RECOVERY_PENDING state (state = 3).
SELECT name                       AS DatabaseName,
       state_desc                 AS State,
       recovery_model_desc        AS RecoveryModel,
       is_in_standby              AS IsInStandby
FROM   sys.databases
WHERE  state = 3
ORDER  BY name;
GO
