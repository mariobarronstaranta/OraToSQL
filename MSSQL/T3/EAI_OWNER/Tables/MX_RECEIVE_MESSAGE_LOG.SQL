
/****** Object:  Table [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]    Script Date: 8/11/2026 5:42:35 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG](
	[ROW_ID] [varchar](32) NULL,
	[CREATED] [datetime2](0) NULL,
	[XML_CONTENT] [xml] NULL,
	[QUEUE_NAME] [varchar](30) NULL,
	[REFERENCE] [varchar](50) NULL,
	[PROCESSED] [datetime2](0) NULL,
	[STATUS] [varchar](10) NULL,
	[DOCNUM] [varchar](20) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.ROW_ID' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'ROW_ID'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.CREATED' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'CREATED'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.XML_CONTENT' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'XML_CONTENT'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.QUEUE_NAME' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'QUEUE_NAME'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.REFERENCE' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'REFERENCE'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.PROCESSED' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'PROCESSED'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.STATUS' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'STATUS'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.DOCNUM' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG', @level2type=N'COLUMN',@level2name=N'DOCNUM'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_SSMA_SOURCE', @value=N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG' , @level0type=N'SCHEMA',@level0name=N'EAI_OWNER', @level1type=N'TABLE',@level1name=N'MX_RECEIVE_MESSAGE_LOG'
GO

