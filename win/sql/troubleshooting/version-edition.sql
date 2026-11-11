-- SQL Server version, edition, and high-availability properties.
SELECT SERVERPROPERTY('ServerName')              AS ServerName,
       SERVERPROPERTY('InstanceName')            AS InstanceName,
       SERVERPROPERTY('ProductVersion')          AS ProductVersion,
       SERVERPROPERTY('ProductLevel')            AS ProductLevel,
       SERVERPROPERTY('ProductUpdateLevel')      AS ProductUpdateLevel,
       SERVERPROPERTY('ProductBuildType')        AS ProductBuildType,
       SERVERPROPERTY('Edition')                 AS Edition,
       SERVERPROPERTY('EngineEdition')           AS EngineEdition,
       SERVERPROPERTY('IsClustered')             AS IsClustered,
       SERVERPROPERTY('IsHadrEnabled')           AS IsHadrEnabled;
GO
