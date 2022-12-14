IF OBJECT_ID('dbo.RefreshParentTaskUpdate') IS NOT NULL
DROP PROCEDURE dbo.RefreshParentTaskUpdate
GO

CREATE PROCEDURE dbo.RefreshParentTaskUpdate 
    @TimeZone varchar(6),
	@DateToday date,
    @Frequency nvarchar(15),
	@errFlag bit OUTPUT,
	@errMessage nvarchar(4000) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @errFlag = 0
	SET @errMessage = 'Parent Task Update'
	BEGIN TRANSACTION
		BEGIN TRY
			UPDATE dbo.ParentTaskUpdate
			SET IsActive = 0
			WHERE IsActive = 1
			AND Frequency = @Frequency
			AND [Date] < @DateToday

			DECLARE @cParentID nvarchar(128), @cParentTaskID nvarchar(128), @cMasterTaskId nvarchar(128) 
			DECLARE @cFrequency nvarchar(50), @cFrequencyPattern nvarchar(128)
			DECLARE @cTimeOfDay  nvarchar(50), @cTime time(7), @cSlotStartTime time(7), @cOrder int
			DECLARE @cIcon nvarchar(255), @cLastXDate date, @cDescription nvarchar(128)
			DECLARE @cAllTime bit, @cEndDate date
			DECLARE @CycleStartDate date, @CycleDay tinyint, @CustRem tinyint, @CustQuo tinyint
			DECLARE @cName nvarchar(128), @cType nvarchar(128)
			DECLARE @cFreqDateString nvarchar(50), @dateVal date
			DECLARE @goAhead bit

			IF @Frequency='Daily'
			BEGIN
				INSERT INTO dbo.ParentTaskUpdate (Id,ParentId,MasterTaskId, ParentTaskId, Name, [Type],
				TimeOfDay,[Time],SlotStartTime, [Order], Icon,[Date],IsActive, Frequency, Description)
				SELECT dbo.NewIDToNVCHAR128(NEWID()), pt.ParentID, pt.MasterTaskId, pt.Id, pt.Name, pt.[Type],
				pt.TimeOfDay, pt.[Time], pt.SlotStartTime, pt.[Order], pt.Icon, @DateToday, 1, pt.Frequency, pt.Description
				FROM dbo.Parent p, dbo.ParentTask pt
				WHERE p.IsActive=1
				--AND p.TimeZone=@TimeZone
				AND p.ID = pt.ParentID
				AND Frequency = @Frequency
				AND (pt.AllTime = 1 or pt.EndDate>=@DateToday)

				UPDATE dbo.ParentTask
				SET LastXDate = @DateToday
				WHERE ParentID in (Select ID from Parent where IsActive=1)
				AND Frequency = @Frequency
				AND LastXDate < @DateToday
				AND (AllTime = 1 or EndDate>=@DateToday)
			END
			ELSE
			BEGIN
				DECLARE ParentTaskCursor CURSOR FOR
				SELECT pt.Id, pt.MasterTaskId, pt.ParentID, pt.Name, pt.[Type], pt.Frequency, pt.FrequencyPattern, 
				pt.TimeOfDay, pt.[Time], pt.SlotStartTime, pt.[Order], pt.Icon, pt.LastXDate, pt.AllTime, pt.EndDate, pt.Description
				FROM dbo.Parent p, dbo.ParentTask pt
				WHERE p.IsActive=1
				--AND p.TimeZone=@TimeZone
				AND p.ID = pt.ParentID
				AND Frequency = @Frequency
				AND (pt.AllTime = 1 or pt.EndDate>=@DateToday)
				OPEN ParentTaskCursor 
				FETCH NEXT from ParentTaskCursor INTO @cParentTaskID, @cMasterTaskId, @cParentID, @cName, @cType,
				@cFrequency, @cFrequencyPattern, @cTimeOfDay, @cTime, @cSlotStartTime, @cOrder, @cIcon, @cLastXDate,
				@cAllTime, @cEndDate, @cDescription
				WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE FreqDateCursor CURSOR FOR
					SELECT value FROM STRING_SPLIT(@cFrequencyPattern,',')
					OPEN FreqDateCursor 
					FETCH NEXT from FreqDateCursor INTO @cFreqDateString
					WHILE @@FETCH_STATUS = 0
					BEGIN
						SET @goAhead = 0
						IF @Frequency='Weekly'
						BEGIN
							SET @CycleStartDate = @DateToday
							SET @CycleDay = datepart(dw,@DateToday)
							if @CycleDay > 2
							begin
								set @CycleStartDate = dateadd(day,(2-@CycleDay),@DateToday)
							end
							else if datepart(dw,@DateToday) = 1
							begin
								set @CycleStartDate = dateadd(day,-6,@DateToday)
							end
							if @CycleStartDate > @cLastXDate
							begin
								SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint),@CycleStartDate)  
								SET @goAhead = 1
								UPDATE dbo.ParentTask 
								SET LastXDate=@CycleStartDate
								WHERE Id=@cParentTaskID
							end
						END
						ELSE IF @Frequency='Monthly'
						BEGIN
							SET @CycleStartDate = @DateToday
							SET @CycleDay = datepart(day,@DateToday)
							if @CycleDay > 1
							begin
								set @CycleStartDate = dateadd(day,(1-@CycleDay),@DateToday)
							end
							if @CycleStartDate > @cLastXDate
							begin
								SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint),EOMONTH(@CycleStartDate,-1))  
								SET @goAhead = 1
								UPDATE dbo.ParentTask 
								SET LastXDate=@CycleStartDate
								WHERE Id=@cParentTaskID
							end
						END
						ELSE -- @Frequency='Custom'
						BEGIN
							SET @CustRem = datediff(day, @cLastXDate, @DateToday) % CAST(@cFreqDateString as tinyint) 
							if @CustRem = 0
							begin
								SET @CustQuo = datediff(day, @cLastXDate, @DateToday) / CAST(@cFreqDateString as tinyint)
								if @CustQuo > 0
								begin 
									SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint)*@CustQuo,@cLastXDate)
									SET @goAhead = 1
									UPDATE dbo.ParentTask 
									SET LastXDate=@dateVal
									WHERE Id=@cParentTaskID
								end 
							end
						END

						IF @goAhead = 1 
						BEGIN
							INSERT INTO dbo.ParentTaskUpdate (Id,ParentId,MasterTaskId, ParentTaskId, Name, [Type],
							TimeOfDay, [Time], SlotStartTime, [Order], Icon,[Date],IsActive,Frequency, Description)
							VALUES (dbo.NewIDToNVCHAR128(NEWID()), @cParentID, @cMasterTaskId, @cParentTaskID, @cName, @cType,
							@cTimeOfDay, @cTime, @cSlotStartTime, @cOrder, @cIcon, @dateVal, 1, @cFrequency, @cDescription)
						END
						FETCH NEXT from FreqDateCursor INTO @cFreqDateString
					END 
					CLOSE FreqDateCursor
					DEALLOCATE FreqDateCursor
					FETCH NEXT from ParentTaskCursor INTO @cParentTaskID, @cMasterTaskId, @cparentID, @cName, @cType,
					@cFrequency, @cFrequencyPattern, @cTimeOfDay, @cTime, @cSlotStartTime, @cOrder, @cIcon, @cLastXDate,
					@cAllTime, @cEndDate, @cDescription
				END
				CLOSE ParentTaskCursor
				DEALLOCATE ParentTaskCursor
			END
		END TRY
		BEGIN CATCH
			ROLLBACK
			SET @errFlag = 1
			SET @errMessage = 'ERROR NUMBER: '+ CONVERT(nvarchar(10), ERROR_NUMBER()) +CHAR(13)+'ERROR MESSAGE: ' + ERROR_MESSAGE() 
		END CATCH
	COMMIT
END
GO

