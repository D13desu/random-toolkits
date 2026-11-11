-- All sp_configure settings with their current, minimum, and maximum values.
SELECT name                AS ConfigurationName,
       value_in_use        AS ValueInUse,
       minimum             AS Minimum,
       maximum             AS Maximum,
       description         AS Description,
       is_dynamic          AS IsDynamic,
       is_advanced         AS IsAdvanced
FROM   sys.configurations
ORDER  BY name;
GO
