IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'PSRC\Modeller')
CREATE LOGIN [PSRC\Modeller] FROM WINDOWS
GO
CREATE USER [PSRC\Modeller] FOR LOGIN [PSRC\Modeller]
GO
