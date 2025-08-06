SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[shifixy_delete_trip]
    @target_recid int
AS
BEGIN
    DECLARE @target_person_id decimal;
    SET @target_person_id = (SELECT person_id FROM HHSurvey.trip WHERE recid = @target_recid);
    EXECUTE HHSurvey.remove_trip @target_recid;
    EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END
GO
