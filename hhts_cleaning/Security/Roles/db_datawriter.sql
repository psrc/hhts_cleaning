
EXEC sp_addrolemember N'db_datawriter', N'Hana'
ALTER ROLE [db_datawriter] ADD MEMBER [PSRC\Clam]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [PSRC\GGibson]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [PSRC\JLin]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [PSRC\MRichards]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [PSRC\SChildress]
GO
