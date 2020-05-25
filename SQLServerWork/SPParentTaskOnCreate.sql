
IF OBJECT_ID('dbo.ParenTaskUpdateOnCreate') IS NOT NULL
DROP PROCEDURE dbo.ParenTaskUpdateOnCreate
GO

CREATE PROCEDURE dbo.ParenTaskUpdateOnCreate 
	@ParentTaskID nvarchar(128),
    @Frequency nvarchar(15),
--    @TimeZone smallint,
	@errFlag bit OUTPUT,
	@errMessage nvarchar(4000) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @errFlag = 0
	SET @errMessage = 'Parent Task Update'
	declare @DateToday date
	declare @TimeZone smallint
	set @TimeZone = 530; --Set to currently Indian Time Zone
	begin transaction
	begin try
		set @DateToday = convert(date, dateadd(minute,@TimeZone%100,dateadd(hour,floor(@TimeZone/100),getdate())) ) 
		declare @StartDate date, @EndDate date, @AllTime bit
		declare @FrequencyPattern nvarchar(128)
		declare @FrequencyDayNum tinyint
		declare @SchedulePeriodStartDay date, @CurrentPeriodStartDay date, @MinusOnePeriodStartDay date, @DateNext date, @cFreqDateString nvarchar(50)
		declare @DaysPast tinyint, @CustRem tinyint

		SELECT @StartDate = StartDate, @EndDate = EndDate, @AllTime = AllTime, @FrequencyPattern = FrequencyPattern
		FROM dbo.ParentTask
		WHERE Id = @ParentTaskID

		if @Frequency='Daily'  
		begin 
			if @StartDate <= @DateToday
			begin
				INSERT INTO dbo.ParentTaskUpdate (Id,ParentId,MasterTaskId, ParentTaskId, Name, [Type], Icon, 
				TimeOfDay,[Time],[Date],IsActive, Frequency, SlotStartTime, Description)
				SELECT dbo.NewIDToNVCHAR128(NEWID()), p.ParentID, p.MasterTaskId, @ParentTaskID, p.Name, p.[Type], p.Icon,
				p.TimeOfDay, p.[Time], @DateToday, 1, p.Frequency, p.SlotStartTime, p.Description
				FROM dbo.ParentTask p
				WHERE p.Id = @ParentTaskID

				UPDATE dbo.ParentTask 
				SET LastXDate=@DateToday
				WHERE Id=@ParentTaskID				
			end
			else
			begin
				UPDATE dbo.ParentTask 
				SET LastXDate=dateadd(day, -1, @StartDate)
				WHERE Id=@ParentTaskID				
			end
		end
		else if @Frequency='Custom' 
		begin
			set @FrequencyDayNum=cast(@FrequencyPattern as tinyint)
			if @StartDate > @DateToday
			begin
				UPDATE dbo.ParentTask 
				SET LastXDate=DateAdd(day, (0-@FrequencyDayNum), @StartDate)
				WHERE Id=@ParentTaskID				
			end
			else
			begin
				SET @DaysPast = DateDiff(day, @StartDate, @DateToday)
				Set @CustRem = @DaysPast % @FrequencyDayNum
				if @CustRem = 0 and (@AllTime > 0 or @DateToday <= @EndDate)
				begin
					INSERT INTO dbo.ParentTaskUpdate (Id,ParentId,MasterTaskId, ParentTaskId, Name, [Type],Icon,
					TimeOfDay,[Time],[Date],IsActive,Frequency, SlotStartTime, Description)
					SELECT dbo.NewIDToNVCHAR128(NEWID()), ParentID, MasterTaskId, @ParentTaskID, Name, [Type],Icon,
					TimeOfDay, [Time], @DateToday, 1, Frequency, SlotStartTime, Description
					FROM dbo.ParentTask 
					WHERE Id = @ParentTaskID
					
					UPDATE dbo.ParentTask 
					SET LastXDate=@DateToday
					WHERE Id=@ParentTaskID				
				end
				else
				begin
					UPDATE dbo.ParentTask 
					SET LastXDate=DateAdd(day, (0-@CustRem), @DateToday)
					WHERE Id=@ParentTaskID				
				end
			end
		end
		else
		begin		
			IF @Frequency='Weekly' 
			begin
				set @SchedulePeriodStartDay =  DateAdd(day, -(datepart(weekday, @StartDate) + 5) % 7, @DateToday)
				set @CurrentPeriodStartDay =  DateAdd(day, -(datepart(weekday, @DateToday) + 5) % 7, @DateToday)
				set @MinusOnePeriodStartDay =  DateAdd(day, -7, @SchedulePeriodStartDay)
			end
			else --@Frequency='Monthly' 
			begin
				set @SchedulePeriodStartDay = dateadd(day, 1, eomonth(@StartDate, -1))
				set @CurrentPeriodStartDay = dateadd(day, 1, eomonth(@DateToday, -1))
				set @MinusOnePeriodStartDay =  DateAdd(month, -1, @SchedulePeriodStartDay)
			end
			if @SchedulePeriodStartDay > @CurrentPeriodStartDay 
			begin
				UPDATE dbo.ParentTask 
				SET LastXDate=@MinusOnePeriodStartDay
				WHERE Id=@ParentTaskID				
			end
			else
			begin
				DECLARE FreqDateCursor CURSOR FOR
				SELECT value FROM STRING_SPLIT(@FrequencyPattern,',')
				OPEN FreqDateCursor 
				FETCH NEXT from FreqDateCursor INTO @cFreqDateString
				WHILE @@FETCH_STATUS = 0
				begin
					set @DateNext = DATEADD(DAY,CAST(@cFreqDateString as tinyint),@CurrentPeriodStartDay)
					if @DateNext >= @DateToday and @DateNext >= @StartDate
					begin
						INSERT INTO dbo.ParentTaskUpdate (Id,ParentId,MasterTaskId, ParentTaskId, Name, [Type],Icon,
						TimeOfDay,[Time],[Date],IsActive,Frequency, SlotStartTime, Description)
						SELECT dbo.NewIDToNVCHAR128(NEWID()), ParentID, MasterTaskId, @ParentTaskID, Name, [Type],Icon,
						TimeOfDay, [Time], @DateNext , 1, Frequency, SlotStartTime, Description
						FROM dbo.ParentTask 
						WHERE Id = @ParentTaskID
					end 
					FETCH NEXT from FreqDateCursor INTO @cFreqDateString
				END 
				CLOSE FreqDateCursor
				DEALLOCATE FreqDateCursor

				UPDATE dbo.ParentTask 
				SET LastXDate=@CurrentPeriodStartDay
				WHERE Id=@ParentTaskID				
			end
		end 
		END TRY
		BEGIN CATCH
			if @@TRANCOUNT>0
				ROLLBACK
			SET @errFlag = 1
			SET @errMessage = 'ERROR NUMBER: '+ CONVERT(nvarchar(10), ERROR_NUMBER()) +CHAR(13)+'ERROR MESSAGE: ' + ERROR_MESSAGE() 
		END CATCH
		if @@TRANCOUNT>0
			COMMIT TRANSACTION
END
GO

