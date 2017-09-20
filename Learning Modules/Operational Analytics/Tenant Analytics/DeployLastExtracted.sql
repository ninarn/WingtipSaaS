-- Connect to and run against the jobaccount database in catalog-<WtpUser> server

-- Run a job to create a table that stores the row version of the last row extracted from tickets, venue and event data
EXEC jobs.sp_add_job
@job_name='DeployLastExtracted',
@description='Creates a table in each tenant to store rowversions for tickets, events and venues',
@enabled=1,
@schedule_interval_type='Once'

EXEC jobs.sp_add_jobstep
@job_name='DeployLastExtracted',
@command=N'
IF (OBJECT_ID(''LastExtracted'')) IS NOT NULL DROP TABLE JobTimestamps
CREATE TABLE [dbo].[LastExtracted]
(
    [LastExtractedVenueRowVersion]  VARBINARY(8) NOT NULL DEFAULT 0x0000000000000000,
    [LastExtractedEventRowVersion]  VARBINARY(8) NOT NULL DEFAULT 0x0000000000000000,
    [LastExtractedTicketRowVersion] VARBINARY(8) NOT NULL DEFAULT 0x0000000000000000,
    [Lock]                          CHAR NOT NULL DEFAULT ''X'',
    CONSTRAINT [CK_LastExtracted_Singleton] CHECK (Lock = ''X''),
    CONSTRAINT [PK_LastExtracted] PRIMARY KEY ([Lock])
)

INSERT INTO [dbo].[LastExtracted]
VALUES (0x0000000000000000, 0x0000000000000000, 0x0000000000000000, ''X'')
',
@credential_name='mydemocred',
@target_group_name='TenantGroup'


--
-- Views
-- Job and Job Execution Information and Status

--View all execution status. 
--Lifecycle should be 'succeeded' to ensure successful creation of tables in each database.
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'DeployLastExtracted'

-- Cleanup
--EXEC [jobs].[sp_delete_job] 'DeployLastExtracted'
--EXEC jobs.sp_start_job 'DeployLastExtracted'