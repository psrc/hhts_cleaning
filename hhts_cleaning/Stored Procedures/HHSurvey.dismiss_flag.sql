SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[dismiss_flag]
    @target_recid int -- optional default
AS
BEGIN
    UPDATE HHSurvey.trip
        SET psrc_resolved = 1
    WHERE recid = @target_recid;
END
GO
