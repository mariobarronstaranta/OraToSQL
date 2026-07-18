
CREATE TABLE [T3].[RF_PROCESOS_LOG](
	[PID] [decimal](10, 0) NULL,
	[PROCESO] [decimal](4, 0) NULL,
	[FECHA_PROC_BATMD] [datetime2](0) NULL,
	[INICIO] [datetime2](0) NULL,
	[FIN] [datetime2](0) NULL,
	[PROCESO_1] [decimal](10, 0) NULL,
	[PROCESO_2] [decimal](10, 0) NULL,
	[PROCESO_3] [decimal](10, 0) NULL,
	[PROCESO_4] [decimal](10, 0) NULL
) ON [PRIMARY]
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logging Table' , @level0type=N'SCHEMA',@level0name=N'T3', @level1type=N'TABLE',@level1name=N'RF_PROCESOS_LOG'
GO