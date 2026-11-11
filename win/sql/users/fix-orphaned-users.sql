-- Remaps an existing database user to an existing server login.
-- Verify that the login and user are the intended pair before running.
USE {{Database}};
GO

ALTER USER {{User}}
WITH LOGIN = {{Login}};
GO
