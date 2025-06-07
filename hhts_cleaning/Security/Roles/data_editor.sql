CREATE ROLE [data_editor]
AUTHORIZATION [dbo]
GO
ALTER ROLE [data_editor] ADD MEMBER [PSRC\GGibson]
GO
ALTER ROLE [data_editor] ADD MEMBER [PSRC\MRichards]
GO
ALTER ROLE [data_editor] ADD MEMBER [PSRC\SChildress]
GO
GRANT EXECUTE TO [data_editor]
