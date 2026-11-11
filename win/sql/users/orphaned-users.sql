-- Lists database users whose SID has no matching server login (orphaned users).
USE {{Database}};
GO

SELECT dp.name                          AS OrphanedUser,
       dp.type_desc                     AS UserType,
       CONVERT(varchar(85), dp.sid, 1)  AS UserSid,
       dp.create_date                   AS Created
FROM   sys.database_principals AS dp
WHERE  dp.type IN ('S', 'U')
  AND  dp.sid IS NOT NULL
  AND  dp.principal_id > 4
  AND  NOT EXISTS
       (
           SELECT 1
           FROM   sys.server_principals AS sp
           WHERE  sp.sid = dp.sid
       )
ORDER  BY dp.name;
GO
