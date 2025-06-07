IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'PSRC\MRichards')
CREATE LOGIN [PSRC\MRichards] FROM WINDOWS
GO
CREATE USER [PSRC\MRichards] FOR LOGIN [PSRC\MRichards]
GO
