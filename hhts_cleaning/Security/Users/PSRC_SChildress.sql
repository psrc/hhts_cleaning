IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'PSRC\SChildress')
CREATE LOGIN [PSRC\SChildress] FROM WINDOWS
GO
CREATE USER [PSRC\SChildress] FOR LOGIN [PSRC\SChildress]
GO
