SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[shifixy_delete_trip]
    @recid int
AS
BEGIN
    DECLARE @target_person_id int;
    SET @target_person_id = (SELECT person_id FROM HHSurvey.trip WHERE recid = @recid);
    EXECUTE HHSurvey.remove_trip @recid;
    EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END
GO
