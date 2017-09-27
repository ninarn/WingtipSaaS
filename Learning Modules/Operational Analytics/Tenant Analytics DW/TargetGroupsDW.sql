--Connect to and run against the jobaccount database in catalog-<WtpUser> server
-- Replace <WtpUser> below with your user name in single quotation marks
DECLARE @WtpUser nvarchar(50);
DECLARE @server1 nvarchar(50);
DECLARE @server2 nvarchar(50);
SET @WtpUser = <WtpUser>;

-- Add a target group containing server(s)
EXEC [jobs].sp_add_target_group @target_group_name = 'TenantGroup'

-- Add a server target member, includes all databases in tenant server
SET @server1 = 'tenants1-' + @WtpUser + '.database.windows.net'

EXEC [jobs].sp_add_target_group_member
@target_group_name = 'TenantGroup',
@membership_type = 'Include',
@target_type = 'SqlServer',
@refresh_credential_name='myrefreshcred',
@server_name=@server1

-- Add a target group containing server(s)
EXEC [jobs].sp_add_target_group @target_group_name = 'AnalyticsGroup'

-- Add a server target member, includes only tenantanalytics database in catalog server
SET @server2 = 'catalog-' + @WtpUser + '.database.windows.net'

-- Doesn't required refresh credential because this target group only contains a single database
EXEC [jobs].sp_add_target_group_member
@target_group_name = 'AnalyticsGroup',
@target_type = 'Sqldatabase',
@membership_type = 'Include',
@server_name=@server2,
@database_name = 'tenantanalytics-dw'

-- cleanup
--EXEC [jobs].[sp_delete_target_group] 'TenantGroup'
--EXEC [jobs].[sp_delete_target_group] 'AnalyticsGroup'
