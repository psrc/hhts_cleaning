IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'PSRC\MOshanreh')
CREATE LOGIN [PSRC\MOshanreh] FROM WINDOWS
GO
CREATE USER [PSRC\MOshanreh] FOR LOGIN [PSRC\MOshanreh]
GO
