SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[shifixy_insert_return_home]
    @target_recid int = NULL,
    @startdatetime nvarchar(19) = NULL,
    @GoogleKey nvarchar(100)
AS
BEGIN

    EXECUTE HHSurvey.insert_return_home @target_recid, @startdatetime, @GoogleKey;
END
GO
