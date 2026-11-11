-- Full allocation and consistency check. Resource intensive and can run for
-- a long time on large databases. Read-only: no REPAIR option is supplied.
DBCC CHECKDB ({{Database}})
WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO
