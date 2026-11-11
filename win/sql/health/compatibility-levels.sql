-- Compatibility level of every database with its friendly SQL Server name.
SELECT name                       AS DatabaseName,
       compatibility_level        AS CompatibilityLevel,
       CASE compatibility_level
            WHEN 100 THEN 'SQL Server 2008 / 2008 R2'
            WHEN 110 THEN 'SQL Server 2012'
            WHEN 120 THEN 'SQL Server 2014'
            WHEN 130 THEN 'SQL Server 2016'
            WHEN 140 THEN 'SQL Server 2017'
            WHEN 150 THEN 'SQL Server 2019'
            WHEN 160 THEN 'SQL Server 2022'
            ELSE 'Unknown / custom'
       END                        AS CompatibilityLevelName
FROM   sys.databases
ORDER  BY name;
GO
