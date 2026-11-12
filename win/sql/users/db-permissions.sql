-- Explicit database permissions granted or denied to principals.
-- Permissions inherited from fixed database roles are not represented here.
USE {{Database}};
GO

SELECT pr.name                AS Principal,
       pr.type_desc           AS PrincipalType,
       perm.state_desc        AS State,
       perm.permission_name   AS Permission,
       perm.class_desc        AS Class,
       ISNULL(OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id), '(database)') AS Securable
FROM   sys.database_permissions AS perm
       JOIN sys.database_principals AS pr
            ON pr.principal_id = perm.grantee_principal_id
ORDER  BY pr.name, perm.permission_name;
GO
