
EXEC sp_addrolemember N'db_owner', N'Hana'
ALTER ROLE [db_owner] ADD MEMBER [PSRC\Clam]
GO
ALTER ROLE [db_owner] ADD MEMBER [PSRC\JLin]
GO
ALTER ROLE [db_owner] ADD MEMBER [PSRC\MJensen]
GO
