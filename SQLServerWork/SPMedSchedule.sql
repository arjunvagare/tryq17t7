
IF OBJECT_ID('dbo.RefreshMedScheduleUpdate') IS NOT NULL
DROP PROCEDURE dbo.RefreshMedScheduleUpdate
GO

CREATE PROCEDURE dbo.RefreshMedScheduleUpdate 
    @TimeZone varchar(6),
	@DateToday date,
    @FrequencyPattern nvarchar(15),
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
			AND FrequencyPattern = @FrequencyPattern

			DECLARE @cparentID nvarchar(128), @cMedicineID nvarchar(128), @cMedSchedID nvarchar(128) 
			DECLARE @cDosage int, @cDosageUnit nvarchar(128)
			DECLARE @cFrequencyPattern nvarchar(50), @cFrequency nvarchar(128)
			DECLARE @cTimeOfDay  nvarchar(50), @cTime time(7)
			DECLARE @cCibum bit, @cPurpose nvarchar(255)
			DECLARE @cPhoto nvarchar(255), @cLastXDate date
			DECLARE @cAllTime bit, @cEndDate date

			DECLARE @cFreqDateString nvarchar(50), @dateVal date
			DECLARE @goAhead bit

			IF @FrequencyPattern='Daily'
			BEGIN
				INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,
				Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive, FrequencyPattern)
				SELECT dbo.NewIDToNVCHAR128(NEWID()), m.ParentID, m.MedicineID, m.Dosage, m.DosageUnit, 
				m.TimeOfDay, m.[Time], m.Cibum, m.Purpose, m.Photo, @DateToday, 1, m.FrequencyPattern
				FROM dbo.Parent p, dbo.MedicineSchedule m
				WHERE p.IsActive=1
				--AND p.TimeZone=@TimeZone
				AND p.ID = m.ParentID
				AND FrequencyPattern = @FrequencyPattern
				AND (m.AllTime = 1 or m.EndDate>=@DateToday)
			END
			ELSE
			BEGIN
				DECLARE ParentMedCursor CURSOR FOR
				SELECT m.Id, m.ParentID, m.MedicineID, m.Dosage, m.DosageUnit, m.FrequencyPattern, m.Frequency, 
				m.TimeOfDay, m.[Time], m.Cibum, m.Purpose, m.Photo, m.LastXDate, m.AllTime, m.EndDate
				FROM dbo.Parent p, dbo.MedicineSchedule m
				WHERE p.IsActive=1
				--AND p.TimeZone=@TimeZone
				AND p.ID = m.ParentID
				AND FrequencyPattern = @FrequencyPattern
				AND (m.AllTime = 1 or m.EndDate>=@DateToday)
				OPEN ParentMedCursor 
				FETCH NEXT from ParentMedCursor INTO @cMedSchedID, @cparentID, @cMedicineID, @cDosage, @cDosageUnit,
				@cFrequencyPattern, @cFrequency, @cTimeOfDay, @cTime, @cCibum, @cPurpose, @cPhoto, @cLastXDate,
				@cAllTime, @cEndDate
				WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE FreqDateCursor CURSOR FOR
					SELECT value FROM STRING_SPLIT(@cFrequency,',')
					OPEN FreqDateCursor 
					FETCH NEXT from FreqDateCursor INTO @cFreqDateString
					WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @FrequencyPattern='Weekly'
						BEGIN
							SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint),@DateToday)  
							SET @goAhead = 1
						END
						ELSE IF @FrequencyPattern='Monthly'
						BEGIN
							SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint),EOMONTH(@DateToday,-1))  
							SET @goAhead = 1
						END
						ELSE -- @FrequencyPattern='Custom'
						BEGIN
							SET @dateVal = DATEADD(DAY,CAST(@cFreqDateString as tinyint),@cLastXDate)
							IF @dateVal = @DateToday
							BEGIN
								SET @goAhead = 1
								UPDATE dbo.MedicineSchedule 
								SET LastXDate=@dateVal
								WHERE Id=@cMedSchedID
							END
							ELSE
							BEGIN
								SET @goAhead = 0
							END
						END

						IF (@goAhead = 1 AND (@cAllTime = 1 OR @dateVal <= @cEndDate))
						BEGIN
							INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,
							Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive,FrequencyPattern)
							VALUES (dbo.NewIDToNVCHAR128(NEWID()), @cParentID, @cMedicineID, @cDosage, @cDosageUnit, 
							@cTimeOfDay, @cTime, @cCibum, @cPurpose, @cPhoto, @dateVal, 1, @cFrequencyPattern)
						END
						FETCH NEXT from FreqDateCursor INTO @cFreqDateString
					END 
					CLOSE FreqDateCursor
					DEALLOCATE FreqDateCursor
					FETCH NEXT from ParentMedCursor INTO @cMedSchedID, @cparentID, @cMedicineID, @cDosage, @cDosageUnit,
					@cFrequencyPattern, @cFrequency, @cTimeOfDay, @cTime, @cCibum, @cPurpose, @cPhoto, @cLastXDate,
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

