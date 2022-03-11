USE [master]
GO

CREATE DATABASE [MckServiceManagement]
ON  PRIMARY 
( NAME = N'MckServiceManagement', FILENAME = N'<<DataFileLocation>>\MckServiceManagement.mdf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
LOG ON 
( NAME = N'MckServiceManagement_log', FILENAME = N'<<LogFileLocation>>\MckServiceManagement_log.ldf' , SIZE = 8192KB , FILEGROWTH = 65536KB )
GO

USE [MckServiceManagement]
GO

CREATE SCHEMA [synch]
GO

USE [MckServiceManagement]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [synch].[LoginSysUsersInfo](
	[SequenceNumber] [smallint] NOT NULL,
	[LoginName] [sysname] NOT NULL,
	[LoginSID] [varbinary](85) NOT NULL,
	[UserName] [sysname] NULL,
	[ActionCode] [char](2) NULL,
	[SystemDatabaseName] [sysname] NULL,
	[ActionNode] [sysname] NOT NULL,
	[SecondoryNode] [sysname] NULL,
	[ProcessedFlag] [char](1) NULL,
	[UserAction] [nvarchar](max) NULL,
	[ProcessedMessage] [nvarchar](500) NULL,
	[ActionDateTime] [datetime] NOT NULL,
	[ErrorCounter] [tinyint] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

ALTER TABLE [synch].[LoginSysUsersInfo] ADD  DEFAULT ('N') FOR [ProcessedFlag]
GO

ALTER TABLE [synch].[LoginSysUsersInfo] ADD  DEFAULT (getdate()) FOR [ActionDateTime]
GO


