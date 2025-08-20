SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[shifixy_dismiss_flag]
    @target_recid int
AS
BEGIN
    DECLARE @target_person_id decimal;
    SET @target_person_id = (SELECT person_id FROM HHSurvey.trip WHERE recid = @target_recid);
    EXECUTE HHSurvey.dismiss_flag @target_recid;
    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END
GO
