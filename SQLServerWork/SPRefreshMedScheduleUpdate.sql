
IF OBJECT_ID('dbo.RefreshMedScheduleUpdate') IS NOT NULL
DROP PROCEDURE dbo.RefreshMedScheduleUpdate
GO

CREATE PROCEDURE dbo.RefreshMedScheduleUpdate 
    @TimeZone varchar(6),
	@DateToday date,
    @Frequency nvarchar(15),
	@errFlag bit OUTPUT,
	@errMessage nvarchar(4000) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @errFlag = 0
	SET @errMessage = 'Medicine Schedule Update'
	BEGIN TRANSACTION
		BEGIN TRY
			UPDATE dbo.MedicineScheduleUpdate
			SET IsActive = 0
			WHERE IsActive = 1
			AND Frequency = @Frequency
			AND [Date] < @DateToday

			DECLARE @cparentID nvarchar(128), @cMedicineID nvarchar(128), @cMedSchedID nvarchar(128) 
			DECLARE @cDosage int, @cDosageUnit nvarchar(128)
			DECLARE @cFrequency nvarchar(50), @cFrequencyPattern nvarchar(128)
			DECLARE @cTimeOfDay  nvarchar(50), @cTime time(7)
			DECLARE @cCibum bit, @cPurpose nvarchar(255)
			DECLARE @cPhoto nvarchar(255), @cLastXDate date
			DECLARE @cAllTime bit, @cEndDate date
			DECLARE @CycleStartDate date, @CycleDay tinyint, @CustRem tinyint, @CustQuo tinyint

			DECLARE @cFreqDateString nvarchar(50), @dateVal date
			DECLARE @goAhead bit

			IF @Frequency='Daily'
			BEGIN
				INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,MedicineScheduleId,
				Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive, Frequency)
				SELECT dbo.NewIDToNVCHAR128(NEWID()), m.ParentID, m.MedicineID, m.Id, m.Dosage, m.DosageUnit, 
				m.TimeOfDay, m.[Time], m.Cibum, m.Purpose, m.Photo, @DateToday, 1, m.Frequency
				FROM dbo.Parent p, dbo.MedicineSchedule m
				WHERE p.IsActive=1
				--AND p.TimeZone=@TimeZone
				AND p.ID = m.ParentID
				AND Frequency = @Frequency
				AND LastXDate < @DateToday
				AND (m.AllTime = 1 or m.EndDate>=@DateToday)

				UPDATE dbo.MedicineSchedule
				SET LastXDate = @DateToday
				WHERE ParentID in (Select ID from Parent where IsActive=1)
				AND Frequency = @Frequency
				AND LastXDate < @DateToday
				AND (AllTime = 1 or EndDate>=@DateToday)
			END
			ELSE
			BEGIN
				DECLARE ParentMedCursor CURSOR FOR
				SELECT m.Id, m.ParentID, m.MedicineID, m.Dosage, m.DosageUnit, m.Frequency, m.FrequencyPattern, 
				m.TimeOfDay, m.[Time], m.Cibum, m.Purpose, m.Photo, m.LastXDate, m.AllTime, m.EndDate
				FROM dbo.Parent p, dbo.MedicineSchedule m
				WHERE p.IsActive=1
				--AND p.TimeZone=@TimeZone
				AND p.ID = m.ParentID
				AND Frequency = @Frequency
				AND (m.AllTime = 1 or m.EndDate>=@DateToday)
				OPEN ParentMedCursor 
				FETCH NEXT from ParentMedCursor INTO @cMedSchedID, @cparentID, @cMedicineID, @cDosage, @cDosageUnit,
				@cFrequency, @cFrequencyPattern, @cTimeOfDay, @cTime, @cCibum, @cPurpose, @cPhoto, @cLastXDate,
				@cAllTime, @cEndDate
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
								set @CycleStartDate = dateadd(day,(2 - @CycleDay),@DateToday)
							end
							else if datepart(dw,@DateToday) = 1
							begin
								set @CycleStartDate = dateadd(day,-6,@DateToday)
							end
							if @CycleStartDate > @cLastXDate
							begin
								SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint),@CycleStartDate)  
								SET @goAhead = 1
								UPDATE dbo.MedicineSchedule 
								SET LastXDate=@CycleStartDate
								WHERE Id=@cMedSchedID
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
								UPDATE dbo.MedicineSchedule 
								SET LastXDate=@CycleStartDate
								WHERE Id=@cMedSchedID
							end
						END
						ELSE -- @Frequency='Custom'
						BEGIN
							SET @CustRem = datediff(day, @cLastXDate, @DateToday) % CAST(@cFreqDateString as tinyint) 
							if @CustRem = 0
							begin
								SET @CustQuo = floor(datediff(day, @cLastXDate, @DateToday) / CAST(@cFreqDateString as tinyint))
								if @CustQuo > 0
								begin 
									SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint)*@CustQuo,@cLastXDate)
									SET @goAhead = 1
									UPDATE dbo.MedicineSchedule 
									SET LastXDate=@dateVal
									WHERE Id=@cMedSchedID
								end 
							end
						END

						IF @goAhead = 1
						BEGIN
							INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,MedicineScheduleId,
							Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive,Frequency)
							VALUES (dbo.NewIDToNVCHAR128(NEWID()), @cParentID, @cMedicineID, @cMedSchedID, @cDosage, @cDosageUnit, 
							@cTimeOfDay, @cTime, @cCibum, @cPurpose, @cPhoto, @dateVal, 1, @cFrequency)
						END
						FETCH NEXT from FreqDateCursor INTO @cFreqDateString
					END 
					CLOSE FreqDateCursor
					DEALLOCATE FreqDateCursor
					FETCH NEXT from ParentMedCursor INTO @cMedSchedID, @cparentID, @cMedicineID, @cDosage, @cDosageUnit,
					@cFrequency, @cFrequencyPattern, @cTimeOfDay, @cTime, @cCibum, @cPurpose, @cPhoto, @cLastXDate,
					@cAllTime, @cEndDate
				END
				CLOSE ParentMedCursor
				DEALLOCATE ParentMedCursor
			END
			
		END TRY
		BEGIN CATCH
			ROLLBACK
			SET @errFlag = 1
			SET @errMessage = 'ERROR NUMBER: '+ CONVERT(nvarchar(10), ERROR_NUMBER()) +CHAR(13)+'ERROR MESSAGE: ' + ERROR_MESSAGE() 
		END CATCH
		if @@TRANCOUNT>0
		COMMIT TRANSACTION
END
GO

