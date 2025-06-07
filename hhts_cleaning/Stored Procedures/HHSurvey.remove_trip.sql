SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
			CREATE PROCEDURE [HHSurvey].[remove_trip] 
				@target_recid int  NULL --Parameter necessary to have passed
			AS BEGIN
			DELETE FROM HHSurvey.trip OUTPUT deleted.* INTO HHSurvey.removed_trip
				WHERE trip.recid = @target_recid;
			END
GO
