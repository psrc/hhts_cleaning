
EXEC sp_addrolemember N'db_ddladmin', N'Shiny'

EXEC sp_addrolemember N'db_ddladmin', N'Hana'
ALTER ROLE [db_ddladmin] ADD MEMBER [PSRC\Clam]
GO
ALTER ROLE [db_ddladmin] ADD MEMBER [PSRC\JLin]
GO
ALTER ROLE [db_ddladmin] ADD MEMBER [PSRC\SChildress]
GO
