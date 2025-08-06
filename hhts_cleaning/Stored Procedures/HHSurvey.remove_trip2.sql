SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [HHSurvey].[remove_trip2] 
    @target_recid int  NULL --Parameter necessary to have passed
AS BEGIN


    DECLARE @target_person_id decimal(19,0) = NULL;
    SET @target_person_id = (SELECT x.person_id FROM HHSurvey.Trip AS x WHERE x.recid=@target_recid);

    DELETE FROM HHSurvey.trip OUTPUT deleted.* INTO HHSurvey.removed_trip
        WHERE trip.recid = @target_recid;

    EXECUTE HHSurvey.generate_error_flags @target_person_id;
END

GO
