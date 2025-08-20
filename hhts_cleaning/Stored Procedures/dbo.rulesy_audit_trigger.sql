SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/* auto-logging trigger for hhts_cleaning.HHSurvey.Trip */

CREATE PROCEDURE [dbo].[rulesy_audit_trigger]
AS
BEGIN

    SET NOCOUNT ON;

    --Remove any audit trail records that may already exist from previous runs of Rulesy.
    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS HHSurvey.tblTripAudit;
    DROP TRIGGER IF EXISTS HHSurvey.tr_trip;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    CREATE TABLE [HHSurvey].[tblTripAudit](
        [Type] [char](1) NULL,
        [recid] [bigint] NOT NULL,
        [FieldName] [varchar](128) NULL,
        [OldValue] [nvarchar](max) NULL,
        [NewValue] [nvarchar](max) NULL,
        [UpdateDate] [datetime] NULL,
        [UserName] [varchar](128) NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
    COMMIT TRANSACTION;

    -- Create the trigger directly without using a variable
    BEGIN TRANSACTION;
    
    EXEC('
        CREATE TRIGGER HHSurvey.tr_trip ON HHSurvey.[trip] 
        FOR INSERT, UPDATE, DELETE
        AS
        BEGIN
            DECLARE @bit int,
                @field int,
                @maxfield int,
                @char int,
                @fieldname varchar(128),
                @TableName varchar(128),
                @SchemaName varchar(128),
                @PKCols varchar(1000),
                @sql varchar(2000), 
                @UpdateDate varchar(21),
                @UserName varchar(128),
                @Type char(1),
                @PKSelect varchar(1000)
                
            SELECT @TableName = ''trip''
            SELECT @SchemaName = ''HHSurvey''

            -- date and user
            SELECT  @UserName = system_user,
                @UpdateDate = convert(varchar(8), getdate(), 112) + '' '' + convert(varchar(12), getdate(), 114)

            -- Action
            IF EXISTS (SELECT * FROM inserted)
                IF EXISTS (SELECT * FROM deleted)
                    SELECT @Type = ''U''
                ELSE
                    SELECT @Type = ''I''
            ELSE
                SELECT @Type = ''D''
            
            -- get list of columns
            SELECT * INTO #ins FROM inserted
            SELECT * INTO #del FROM deleted
            
            -- Get primary key columns for full outer join
            SELECT  @PKCols = coalesce(@PKCols + '' and'', '' on'') + '' i.['' + c.COLUMN_NAME + ''] = d.['' + c.COLUMN_NAME + '']''
            FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk,
                INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
            WHERE   pk.TABLE_NAME = @TableName
            AND CONSTRAINT_TYPE = ''PRIMARY KEY''
            AND c.TABLE_NAME = pk.TABLE_NAME
            AND c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
            
            -- Get primary key select for insert
            SELECT  @PKSelect = coalesce(@PKSelect+'','','''') + ''convert(varchar(100),coalesce(i.['' + COLUMN_NAME +''],d.['' + COLUMN_NAME + '']))'' 
            FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk,
                INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
            WHERE   pk.TABLE_NAME = @TableName
            AND pk.TABLE_SCHEMA = @SchemaName
            AND c.TABLE_SCHEMA = @SchemaName
            AND CONSTRAINT_TYPE = ''PRIMARY KEY''
            AND c.TABLE_NAME = pk.TABLE_NAME
            AND c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
            ORDER BY c.ORDINAL_POSITION

            IF @PKCols IS NULL
            BEGIN
                RAISERROR(''no PK on table %s'', 16, -1, @TableName)
                RETURN
            END

            SELECT @field = 0, @maxfield = max(ORDINAL_POSITION) 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = @TableName 
                AND TABLE_SCHEMA = @SchemaName

            WHILE @field < @maxfield
            BEGIN
                SELECT @field = min(ORDINAL_POSITION) 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_NAME = @TableName 
                    AND ORDINAL_POSITION > @field 
                    AND TABLE_SCHEMA = @SchemaName
                    AND data_type NOT IN(''geography'',''geometry'')

                SELECT @bit = (@field - 1 )% 8 + 1
                SELECT @bit = power(2,@bit - 1)
                SELECT @char = ((@field - 1) / 8) + 1

                IF ( substring(COLUMNS_UPDATED(),@char, 1) & @bit > 0 OR @Type IN (''I'',''D'') )
                BEGIN
                    SELECT @fieldname = COLUMN_NAME 
                    FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_NAME = @TableName 
                        AND ORDINAL_POSITION = @field 
                        AND TABLE_SCHEMA = @SchemaName

                    SELECT @sql = ''insert into HHSurvey.tblTripAudit (Type, recid, FieldName, OldValue, NewValue, UpdateDate, UserName)''
                    SELECT @sql = @sql + '' select '''''' + @Type + ''''''''
                    SELECT @sql = @sql + '','' + @PKSelect
                    SELECT @sql = @sql + '','''''' + @fieldname + ''''''''
                    SELECT @sql = @sql + '',convert(varchar(max),d.['' + @fieldname + ''])''
                    SELECT @sql = @sql + '',convert(varchar(max),i.['' + @fieldname + ''])''
                    SELECT @sql = @sql + '','''''' + @UpdateDate + ''''''''
                    SELECT @sql = @sql + '','''''' + @UserName + ''''''''
                    SELECT @sql = @sql + '' from #ins i full outer join #del d''
                    SELECT @sql = @sql + @PKCols
                    SELECT @sql = @sql + '' where i.['' + @fieldname + ''] <> d.['' + @fieldname + '']''
                    SELECT @sql = @sql + '' or (i.['' + @fieldname + ''] is null and  d.['' + @fieldname + ''] is not null)'' 
                    SELECT @sql = @sql + '' or (i.['' + @fieldname + ''] is not null and  d.['' + @fieldname + ''] is null)''
                    
                    EXEC (@sql)
                END
            END
        END
    ');
    
    COMMIT TRANSACTION;
    
    ALTER TABLE HHSurvey.Trip DISABLE TRIGGER tr_trip;
END
GO
