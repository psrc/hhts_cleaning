SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[shifixy_after_edits]
    @target_person_id decimal = NULL -- optional default
AS
BEGIN
    EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END
GO
