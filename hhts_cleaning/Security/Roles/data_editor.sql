CREATE ROLE [data_editor]
AUTHORIZATION [dbo]
EXEC sp_addrolemember N'data_editor', N'PSRC\MOshanreh'
GRANT EXECUTE TO [data_editor]

GO
ALTER ROLE [data_editor] ADD MEMBER [PSRC\GGibson]
GO
ALTER ROLE [data_editor] ADD MEMBER [PSRC\MRichards]
GO
