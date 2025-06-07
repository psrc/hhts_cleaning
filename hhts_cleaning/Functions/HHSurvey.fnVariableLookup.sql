SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE function [HHSurvey].[fnVariableLookup](@VarName nvarchar(50))
returns table 
as
return
select [variable], [value] as [code], [label] from HHSurvey.CodebookValues where variable = @VarName
GO
