CREATE TABLE AgentFixture.syssessions(session_id int);
CREATE TABLE AgentFixture.sysjobactivity(job_id uniqueidentifier,session_id int,start_execution_date datetime,stop_execution_date datetime);
CREATE TABLE AgentFixture.sysjobhistory(job_id uniqueidentifier,instance_id int,run_date int,run_time int,run_duration int,run_status int,step_id int);
CREATE TABLE AgentFixture.sysjobschedules(job_id uniqueidentifier,schedule_id int,next_run_date int,next_run_time int);
CREATE TABLE AgentFixture.sysjobsteps(job_id uniqueidentifier,step_id int,command nvarchar(max));
CREATE TABLE AgentFixture.sysjobs(job_id uniqueidentifier,owner_sid varbinary(85),enabled tinyint,name nvarchar(128));
CREATE TABLE AgentFixture.sysschedules(schedule_id int,freq_type int,freq_interval int,freq_subday_type int,
 freq_subday_interval int,freq_relative_interval int,freq_recurrence_factor int,active_start_date int,
 active_start_time int,active_end_date int,active_end_time int);
GO
CREATE FUNCTION AgentFixture.agent_datetime(@Date int,@Time int) RETURNS datetime
AS BEGIN
 RETURN DATEADD(second,(@Time/10000)*3600+((@Time%10000)/100)*60+@Time%100,
 CONVERT(datetime,CONVERT(char(8),@Date),112));
END;
GO
DECLARE @Job uniqueidentifier='00000000-0000-0000-0000-000000000001';
INSERT AgentFixture.sysjobs VALUES (@Job,SUSER_SID(),1,'Prueba_JOB_REFRESH');
INSERT EAI_OWNER.Job_Oracle_SQLAgent_Map(Oracle_Job_No,SqlAgent_Job_Id,Schedule_Id,Last_Interval,Is_Active)
VALUES(849,@Job,1,REPLICATE('X',300),1);
INSERT AgentFixture.syssessions VALUES (1),(2);
INSERT AgentFixture.sysjobactivity VALUES (@Job,2,'20261008 10:00:00',NULL),(@Job,1,'20260101',NULL);
INSERT AgentFixture.sysjobhistory VALUES
 (@Job,1,20261007,93000,10203,1,0),(@Job,2,20261008,80000,5,0,0),(@Job,3,20261008,90000,7,0,0);
INSERT AgentFixture.sysjobschedules VALUES (@Job,1,20261009,123456);
INSERT AgentFixture.sysjobsteps VALUES (@Job,1,'EXEC EAI.SF_CFDI_OPEN_ITEMS 0;');
INSERT AgentFixture.sysschedules VALUES (1,4,1,4,10,0,1,20260101,50000,99991231,235959);
GO
