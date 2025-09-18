
EXEC sp_addrolemember N'db_datareader', N'PSRC\MOshanreh'

EXEC sp_addrolemember N'db_datareader', N'Shiny'

EXEC sp_addrolemember N'db_datareader', N'Hana'
ALTER ROLE [db_datareader] ADD MEMBER [PSRC\BLee]
GO
ALTER ROLE [db_datareader] ADD MEMBER [PSRC\Clam]
GO
ALTER ROLE [db_datareader] ADD MEMBER [PSRC\GGibson]
GO
ALTER ROLE [db_datareader] ADD MEMBER [PSRC\JLin]
GO
ALTER ROLE [db_datareader] ADD MEMBER [PSRC\Modeller]
GO
ALTER ROLE [db_datareader] ADD MEMBER [PSRC\MRichards]
GO
