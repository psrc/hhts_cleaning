SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[shifixy_insert_reverse_trip]
    @recid int, 
    @startdatetime nvarchar(19)
AS
BEGIN
    DECLARE @target_person_id int;
    SET @target_person_id = (SELECT person_id FROM HHSurvey.trip WHERE recid = @recid);
    EXECUTE HHSurvey.insert_reverse_trip @recid, @startdatetime;
    EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END
GO
