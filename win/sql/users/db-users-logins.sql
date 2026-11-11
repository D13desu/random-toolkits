-- Database users joined to their matching server login by SID.
USE {{Database}};
GO

SELECT dp.name                                AS DatabaseUser,
       dp.type_desc                           AS UserType,
       ISNULL(sp.name, '(no matching login)') AS ServerLogin,
       sp.type_desc                           AS LoginType,
       sp.is_disabled                         AS LoginDisabled
FROM   sys.database_principals AS dp
       LEFT JOIN sys.server_principals AS sp
              ON sp.sid = dp.sid
WHERE  dp.type IN ('S', 'U')
  AND  dp.principal_id > 4
ORDER  BY dp.name;
GO
