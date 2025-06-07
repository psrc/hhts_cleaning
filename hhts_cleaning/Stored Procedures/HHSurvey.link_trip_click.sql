SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[link_trip_click]
			@ref_recid int = NULL
		
			AS BEGIN
		SET NOCOUNT OFF;
		DECLARE @recid_list nvarchar(255) = NULL
		IF (SELECT Elmer.dbo.rgx_find(Elmer.dbo.TRIM(t.psrc_comment),'^(\d+,?)+$',1) FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid) = 1
			BEGIN
			SELECT @recid_list = (SELECT Elmer.dbo.TRIM(t.psrc_comment) FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid)
			EXECUTE HHSurvey.link_trip_via_id @recid_list;
			SELECT @recid_list = NULL, @ref_recid = NULL
			END
		END
GO
