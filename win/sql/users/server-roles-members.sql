-- Fixed and user-defined server roles and their members (server-scoped).
SELECT r.name                 AS ServerRole,
       m.name                 AS Member,
       m.type_desc            AS MemberType,
       m.is_disabled          AS MemberDisabled
FROM   sys.server_role_members AS rm
       JOIN sys.server_principals AS r
            ON r.principal_id = rm.role_principal_id
       JOIN sys.server_principals AS m
            ON m.principal_id = rm.member_principal_id
ORDER  BY r.name, m.name;
GO
