SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[dismiss_flag]
    @target_recid int = NULL, -- optional default
    @target_person_id decimal = NULL -- optional default
AS
BEGIN
    UPDATE HHSurvey.trip
        SET psrc_resolved = 1
    WHERE recid = @target_recid;
    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END
GO
