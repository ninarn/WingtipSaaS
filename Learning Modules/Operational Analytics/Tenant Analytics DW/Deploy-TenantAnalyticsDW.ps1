<#
.SYNOPSIS
  Creates an Operational Analytics DW database for tenant query data

.DESCRIPTION
  Creates the operational tenant analytics DW database for result sets queries from Elastic jobs. Database is created in the resource group
  created when the WTP application was deployed.

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$WtpResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$WtpUser
)

Import-Module $PSScriptRoot\..\..\Common\SubscriptionManagement -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription

Import-Module $PSScriptRoot\..\..\WtpConfig -Force

$config = Get-Configuration

$catalogServerName = $($config.CatalogServerNameStem) + $WtpUser
$databaseName = $config.TenantAnalyticsDWDatabaseName

# Check if Analytics DW database has already been created 
$TenantAnalyticsDWDatabaseName = Get-AzureRmSqlDatabase `
                -ResourceGroupName $WtpResourceGroupName `
                -ServerName $catalogServerName `
                -DatabaseName $databaseName `
                -ErrorAction SilentlyContinue

if($TenantAnalyticsDWDatabaseName)
{
    Write-Output "Tenant Analytics DW database '$databaseName' already exists."
    exit
}

Write-output "Initializing the DW database '$databaseName'..."

# Create the tenant analytics DW database
New-AzureRmSqlDatabase `
    -ResourceGroupName $WtpResourceGroupName `
    -ServerName $catalogServerName `
    -DatabaseName $databaseName `
    -RequestedServiceObjectiveName "DW400" `
    > $null

# Creating tables in tenant analytics database
$commandText = "
-- Create table for storing raw tickets data. 
IF (OBJECT_ID('TicketsRawData')) IS NOT NULL DROP TABLE TicketsRawData
CREATE TABLE [dbo].[TicketsRawData](
	[TicketPurchaseId] [int] NOT NULL,
	[CustomerEmailId] [int] NOT NULL,
	[VenueId] [int] NOT NULL,
	[CustomerPostalCode] [char](10) NOT NULL,
	[CustomerCountryCode] [char](3) NOT NULL,
	[EventId] [int] NOT NULL,
	[RowNumber] [int] NOT NULL,
	[SeatNumber] [int] NOT NULL,
	[PurchaseTotal] [money] NOT NULL,
	[PurchaseDate] [datetime] NOT NULL,
	[internal_execution_id] [uniqueidentifier] NULL,
	[RawTicketId] int identity(1,1) NOT NULL
)
WITH
(DISTRIBUTION = ROUND_ROBIN,
CLUSTERED COLUMNSTORE INDEX
)
GO

--Create table for storing raw venues and events data. 
IF (OBJECT_ID('VenuesEventsRawData')) IS NOT NULL DROP TABLE VenuesEventsRawData
CREATE TABLE [dbo].[VenuesEventsRawData](
	[VenueId] [int] NULL,
	[VenueName] [nvarchar](50) NULL,
	[VenueType] [char](30) NULL,
	[VenuePostalCode] [char](10) NULL,
    [VenueCountryCode] [char](3) NULL,
	[VenueCapacity] [int] NULL,
	[EventId] [int] NULL,
	[EventName] [nvarchar](50) NULL,
	[EventSubtitle] [nvarchar](50) NULL,
	[EventDate] [datetime] NULL,
	[internal_execution_id] [uniqueidentifier] NULL,
	[RawVenueEventId] int identity(1,1) NOT NULL
)
WITH
(DISTRIBUTION = ROUND_ROBIN,
CLUSTERED COLUMNSTORE INDEX
)
GO

--Create fact and dimension tables for the star-schema
-- Create a tickets fact table in tenantanalytics database 
IF (OBJECT_ID('fact_Tickets')) IS NOT NULL DROP TABLE fact_Tickets
CREATE TABLE [dbo].[fact_Tickets] 
						([TicketPurchaseId] [int] NOT NULL,
						[EventId] [int] NOT NULL,
						[CustomerEmailId] [int] NOT NULL,
						[VenueID] [int] NOT NULL,
						[PurchaseDateID ] [int] NOT NULL,
						[PurchaseTotal] [money] NOT NULL,
						[DaysToGo] [int] NOT NULL,
						[RowNumber] [int] NOT NULL,
						[SeatNumber] [int] NOT NULL)
GO

-- Create an event dimension table in tenantanalytics database 
IF (OBJECT_ID('dim_Events')) IS NOT NULL DROP TABLE dim_Events
CREATE TABLE [dbo].[dim_Events] 
						([VenueId] [int] NOT NULL,
						[EventId] [int] NOT NULL,
						[EventName] [nvarchar](50) NOT NULL,
						[EventSubtitle] [nvarchar](50) NULL,
						[EventDate] [datetime] NOT NULL)
GO

-- Create a venue dimension table in tenantanalytics database 
IF (OBJECT_ID('dim_Venues')) IS NOT NULL DROP TABLE dim_Venues
CREATE TABLE [dbo].[dim_Venues] 
						([VenueId] [int] NOT NULL,
						[VenueName] [nvarchar](50) NOT NULL,
						[VenueType] [char](30) NOT NULL,
						[VenueCapacity] [int] NOT NULL,
						[VenuepostalCode] [char](10) NULL,
						[VenueCountryCode] [char](3) NOT NULL)
GO

-- Create a customer dimension table in tenantanalytics database 
IF (OBJECT_ID('dim_Customers')) IS NOT NULL DROP TABLE dim_Customers
CREATE TABLE [dbo].[dim_Customers] 
						([CustomerEmailId] [int] NOT NULL,
						[CustomerPostalCode] [char](10) NOT NULL,
						[CustomerCountryCode] [char](3) NOT NULL)
GO

--Create a date dimension table
IF (OBJECT_ID('dim_Dates')) IS NOT NULL DROP TABLE dim_Dates
CREATE TABLE [dbo].[dim_Dates](
	[PurchaseDateID] [int] NULL,
	[DateValue] [date] NULL,
	[DateYear] [int] NULL,
	[DateMonth] [int] NULL,
	[DateDay] [int] NULL,
	[DateDayOfYear] [int] NULL,
	[DateWeekday] [int] NULL,
	[DateWeek] [int] NULL,
	[DateQuarter] [int] NULL,
	[DateMonthName] [nvarchar](30) NULL,
	[DateQuarterName] [nvarchar](31) NULL,
	[DateWeekdayName] [nvarchar](30) NULL,
	[MonthYear] [nvarchar](34) NULL
)
GO

CREATE PROCEDURE [dbo].[sp_ShredRawExtractedData]
AS

-- Variable to get the max ID of the source table
DECLARE @SourceLastTimestamp binary(8) = (SELECT MAX(RawTicketId) FROM  [dbo].[TicketsRawData])
DECLARE @SourceVELastTimestamp binary(8) = (SELECT MAX(RawVenueEventId) FROM  [dbo].[VenuesEventsRawData])

--Use CTAs (create table as) for merging the old and new data


-- Merge purchase date from raw data to the dimension date table
CREATE TABLE [dbo].[stage_DimDates]
WITH (CLUSTERED INDEX(PurchaseDateID), DISTRIBUTION = ROUND_ROBIN)
AS
-- New rows and new versions of rows
SELECT DISTINCT PurchaseDateID = cast(replace(cast( convert(date, s.PurchaseDate) as varchar(25)),'-','')as int)
						,DateValue = convert(date, s.PurchaseDate)
						,DateYear = DATEPART(year,  s.PurchaseDate) 
						,DateMonth = DATEPART(month, s.PurchaseDate)  
						,DateDay = DATEPART(day,  s.PurchaseDate)  
						,DateDayOfYear = DATEPART(dayofyear,  s.PurchaseDate)  
						,DateWeekday = DATEPART(weekday,  s.PurchaseDate)
						,DateWeek = DATEPART(week,  s.PurchaseDate)
						,DateQuarter = DATEPART(quarter,  s.PurchaseDate)						
						,DateMonthName = DATENAME(month,  s.PurchaseDate)						
						,DateQuarterName = 'Q'+DATENAME(quarter,  s.PurchaseDate)						
						,DateWeekdayName = DATENAME(weekday,  s.PurchaseDate)
						,MonthYear = LEFT(DATENAME(month,  s.PurchaseDate),3)+'-'+DATENAME(year,  s.PurchaseDate)  
	   FROM [dbo].[TicketsRawData] s WHERE RawTicketId <= @SourceLastTimestamp
UNION ALL  
-- Keep rows that are not being touched
SELECT      d.PurchaseDateID, d.DateValue, d.DateYear, d.DateMonth, d.DateDay, d.DateDayOfYear, d.DateWeekday, d.DateWeek, d.DateQuarter, d.DateMonthName, d.DateQuarterName, d.DateWeekdayName, d.MonthYear
FROM      [dbo].[dim_Dates] AS d
WHERE NOT EXISTS
(   SELECT  *
    FROM     [dbo].[TicketsRawData] s
    WHERE   cast(replace(cast( convert(date, s.PurchaseDate) as varchar(25)),'-','')as int) = d.PurchaseDateID
);
DROP TABLE [dbo].[dim_Dates];
-- staging table is the new dimension table
RENAME OBJECT [dbo].[stage_DimDates] TO [dim_Dates];
IF OBJECT_ID('[dbo].[stage_DimDates]') IS NOT NULL  
DROP TABLE [dbo].[stage_DimDates];


-- Merge customers from the raw data to the dimension table
CREATE TABLE [dbo].[stage_DimCustomer]
WITH (CLUSTERED INDEX(CustomerEmailId), DISTRIBUTION = ROUND_ROBIN)
AS
-- New rows and new versions of rows
SELECT DISTINCT    c.CustomerEmailId, c.CustomerPostalCode, c.CustomerCountryCode
FROM      [dbo].[TicketsRawData] AS c
WHERE RawTicketId <= @SourceLastTimestamp
UNION ALL  
-- Keep rows that are not being touched
SELECT      c.CustomerEmailId
,           c.CustomerPostalCode
,           c.CustomerCountryCode
FROM      [dbo].[dim_Customers] AS c
WHERE NOT EXISTS
(   SELECT  s.CustomerEmailId, s.CustomerPostalCode, s.CustomerCountryCode
    FROM     [dbo].[TicketsRawData] s
    WHERE   s.[CustomerEmailId] = c.[CustomerEmailId]
);
DROP TABLE [dbo].[dim_Customers];
RENAME OBJECT dbo.[stage_DimCustomer] TO [dim_Customers];
IF OBJECT_ID('[dbo].[stage_DimCustomer]') IS NOT NULL  
DROP TABLE [dbo].[stage_DimCustomer];

		   
-- Merge tickets from raw data to the fact table
CREATE TABLE [dbo].[stage_fact_Tickets]
WITH (DISTRIBUTION = HASH(VenueId),
  CLUSTERED COLUMNSTORE INDEX)
AS
-- New rows and new versions of rows
SELECT DISTINCT   t.TicketPurchaseId
				 ,t.EventId
				 ,t.CustomerEmailId	
				 ,t.VenueId
				 ,PurchaseDateId = cast(replace(cast(convert(date, t.PurchaseDate) as varchar(25)),'-','')as int)
				 ,t.PurchaseTotal			
				 ,DaysToGo =  DATEDIFF(d, CAST(t.PurchaseDate AS DATE), CAST(ve.EventDate AS DATE))
				 ,t.RowNumber
				 ,t.SeatNumber
FROM [dbo].[TicketsRawData] AS t
INNER JOIN [dbo].[VenuesEventsRawData] ve on t.VenueId = ve.VenueId AND t.EventId = ve.EventId
WHERE RawTicketId <= @SourceLastTimestamp
UNION ALL  
-- Keep rows that are not being touched
SELECT ft.TicketPurchaseId, ft.EventId, ft.CustomerEmailId, ft.VenueId, ft.PurchaseDateId, ft.PurchaseTotal, ft.DaysToGo, ft.RowNumber, ft.SeatNumber
FROM      [dbo].[fact_Tickets] AS ft
WHERE NOT EXISTS
(   SELECT   *
    FROM [dbo].[TicketsRawData] t
INNER JOIN [dbo].[VenuesEventsRawData] ve on t.VenueId = ve.VenueId AND t.EventId = ve.EventId
);
DROP TABLE [dbo].[fact_Tickets];
RENAME OBJECT dbo.[stage_fact_Tickets] TO [fact_Tickets];
IF OBJECT_ID('[dbo].[stage_fact_Tickets]') IS NOT NULL  
DROP TABLE [dbo].[stage_fact_Tickets];

--dim_Events populate
CREATE TABLE [dbo].[stage_dim_Events]
WITH (CLUSTERED INDEX(VenueId, EventId), DISTRIBUTION = ROUND_ROBIN)
AS
-- New rows and new versions of rows
SELECT DISTINCT   ve.VenueId, ve.EventId, ve.EventName, ve.EventSubtitle, ve.EventDate
FROM      [dbo].[VenuesEventsRawData] AS ve
WHERE RawVenueEventId <= @SourceVELastTimestamp
UNION ALL  
-- Keep rows that are not being touched
SELECT      e.VenueId, e.EventId, e.EventName, e.EventSubtitle, e.EventDate
FROM      [dbo].[dim_Events] AS e
WHERE NOT EXISTS
(   SELECT   ve.VenueId, ve.EventId, ve.EventName, ve.EventSubtitle, ve.EventDate
    FROM     [dbo].[VenuesEventsRawData] ve
    WHERE   ve.[VenueId] = e.[VenueId] AND ve.[EventId] = e.[EventId]
);
DROP TABLE [dbo].[dim_Events];
RENAME OBJECT dbo.[stage_dim_Events] TO [dim_Events];
IF OBJECT_ID('[dbo].[stage_dim_Events]') IS NOT NULL  
DROP TABLE [dbo].[stage_dim_Events];

-- dim_Venues populate
CREATE TABLE [dbo].[stage_dim_Venues]
WITH (CLUSTERED INDEX(VenueId), DISTRIBUTION = ROUND_ROBIN)
AS
-- New rows and new versions of rows
SELECT DISTINCT    ve.VenueId, ve.VenueName, ve.VenueType, ve.VenueCapacity, ve.VenuePostalCode, ve.VenueCountryCode
FROM      [dbo].[VenuesEventsRawData] AS ve
WHERE RawVenueEventId <= @SourceVELastTimestamp
UNION ALL  
-- Keep rows that are not being touched
SELECT      v.VenueId, v.VenueName, v.VenueType, v.VenueCapacity, v.VenuePostalCode, v.VenueCountryCode
FROM      [dbo].[dim_Venues] AS v
WHERE NOT EXISTS
(   SELECT   ve.VenueId, ve.VenueName, ve.VenueType, ve.VenueCapacity, ve.VenuePostalCode, ve.VenueCountryCode
    FROM     [dbo].[VenuesEventsRawData] ve
    WHERE   ve.[VenueId] = v.[VenueId]
);
DROP TABLE [dbo].[dim_Venues];
RENAME OBJECT dbo.[stage_dim_Venues] TO [dim_Venues];
IF OBJECT_ID('[dbo].[stage_dim_Venues]') IS NOT NULL  
DROP TABLE [dbo].[stage_dim_Venues];

--Delete the rows in the source table already shredded
DELETE FROM TicketsRawData
WHERE RawTicketId <= @SourceLastTimestamp


DELETE FROM [dbo].[VenuesEventsRawData]
WHERE RawVenueEventId <= @SourceVELastTimestamp
GO
"

$catalogServerName = $config.catalogServerNameStem + $WtpUser
$fullyQualifiedCatalogServerName = $catalogServerName + ".database.windows.net"

Invoke-SqlcmdWithRetry `
-ServerInstance $fullyQualifiedCatalogServerName `
-Username $config.CatalogAdminUserName `
-Password $config.CatalogAdminPassword `
-Database $databaseName `
-Query $commandText `
-ConnectionTimeout 30 `
-QueryTimeout 30 `
> $null  