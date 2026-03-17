-- =============================================================================
-- New Relic MSSQL OTel - SQL User Setup
-- Repository: https://github.com/newrelic-forks/nrdot-collector-components/tree/feature/otel-mssql-qpm-receiver/receiver/newrelicsqlserverreceiver
--
-- Placeholders replaced at runtime by the recipe:
--   {USERNAME}  - SQL login name (default: newrelic)
--   {PASSWORD}  - SQL login password
--
-- Permissions granted:
--   Instance-level : VIEW SERVER STATE, VIEW ANY DEFINITION, VIEW ANY DATABASE
--   Per user DB    : VIEW DATABASE STATE, VIEW DEFINITION, db_datareader
-- =============================================================================

USE [master];

-- Create login if it does not already exist; update password if it does
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'{USERNAME}')
BEGIN
    CREATE LOGIN [{USERNAME}] WITH PASSWORD = '{PASSWORD}';
    PRINT 'Login created: {USERNAME}';
END
ELSE
BEGIN
    ALTER LOGIN [{USERNAME}] WITH PASSWORD = '{PASSWORD}';
    PRINT 'Login already exists; password updated: {USERNAME}';
END;

-- Instance-level permissions
GRANT VIEW SERVER STATE   TO [{USERNAME}];
GRANT VIEW ANY DEFINITION TO [{USERNAME}];
GRANT VIEW ANY DATABASE   TO [{USERNAME}];

-- Grant read access privileges to all online non-system user databases
DECLARE @name SYSNAME;
DECLARE db_cursor CURSOR READ_ONLY FORWARD_ONLY FOR
    SELECT [name]
    FROM [master].[sys].[databases]
    WHERE [name] NOT IN ('master', 'msdb', 'tempdb', 'model', 'rdsadmin', 'distribution')
      AND [state] = 0;  -- Only online databases

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @name;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Processing database: ' + @name;

        EXEC('USE [' + @name + '];
              IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''{USERNAME}'')
              BEGIN
                  CREATE USER [{USERNAME}] FOR LOGIN [{USERNAME}];
              END;
              GRANT VIEW DATABASE STATE TO [{USERNAME}];
              GRANT VIEW DEFINITION    TO [{USERNAME}];
              ALTER ROLE db_datareader ADD MEMBER [{USERNAME}];');

        PRINT 'Success: ' + @name;
    END TRY
    BEGIN CATCH
        PRINT 'Error on ' + @name + ': ' + ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM db_cursor INTO @name;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;
