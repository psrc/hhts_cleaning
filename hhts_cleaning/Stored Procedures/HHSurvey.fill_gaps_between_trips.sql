SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [HHSurvey].[fill_gaps_between_trips]
  @GoogleKey NVARCHAR(100),
  @Debug BIT = 0,
  @Seed BIGINT = NULL
AS
BEGIN
  SET NOCOUNT ON;
  -- Minimal test: DO NOT select gap_id from the function; just count rows.
  DECLARE @cnt INT;
  SELECT @cnt = COUNT(*) FROM HHSurvey.fnIdentifyGaps(500);
  IF @Debug=1 SELECT @cnt AS gap_row_count;
END;
GO
