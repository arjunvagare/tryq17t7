
IF OBJECT_ID('dbo.MedScheduleUpdateOnCreate') IS NOT NULL
DROP PROCEDURE dbo.MedScheduleUpdateOnCreate
GO

CREATE PROCEDURE dbo.MedScheduleUpdateOnCreate 
	@MedicineScheduleID nvarchar(128),
    @FrequencyPattern nvarchar(15),
--    @TimeZone smallint,
	@errFlag bit OUTPUT,
	@errMessage nvarchar(4000) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET @errFlag = 0
	SET @errMessage = 'Medicine Schedule Update'
	declare @DateToday date
	declare @TimeZone smallint
	set @TimeZone = 530; --Set to currently Indian Time Zone
	begin transaction
	begin try
		set @DateToday = convert(date, dateadd(minute,@TimeZone%100,dateadd(hour,floor(@TimeZone/100),getdate())) ) 
		declare @StartDate  date
		DECLARE @Frequency nvarchar(128)
		declare @FrequencyDayNum tinyint
		declare @PeriodStartDay date, @DateNext date, @cFreqDateString nvarchar(50)

		SELECT @StartDate = StartDate, @Frequency = Frequency
		FROM dbo.MedicineSchedule
		WHERE Id = @MedicineScheduleID

		if @FrequencyPattern='Daily'  
		begin 
			if @StartDate <= @DateToday
			begin
				INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,
				Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive, FrequencyPattern)
				SELECT dbo.NewIDToNVCHAR128(NEWID()), m.ParentID, m.MedicineID, m.Dosage, m.DosageUnit, 
				m.TimeOfDay, m.[Time], m.Cibum, m.Purpose, m.Photo, @DateToday, 1, m.FrequencyPattern
				FROM dbo.MedicineSchedule m
				WHERE m.Id = @MedicineScheduleID
			end
		end
		else if @FrequencyPattern='Custom' 
		begin
			if @StartDate = @DateToday 
			begin
				INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,
				Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive,FrequencyPattern)
				SELECT dbo.NewIDToNVCHAR128(NEWID()), ParentID, MedicineID, Dosage, DosageUnit, 
				TimeOfDay, [Time], Cibum, Purpose, Photo, @DateToday, 1, FrequencyPattern
				FROM dbo.MedicineSchedule 
				WHERE Id = @MedicineScheduleID
				
			end
			else
			begin

				set @FrequencyDayNum=cast(@Frequency as tinyint)
				set @DateNext = dateadd(day, @FrequencyDayNum, @StartDate)
				if  @DateNext <= @DateToday
				begin
					if  (datediff(day, @DateNext, @DateToday) % @FrequencyDayNum) = 0
					begin
						INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,
						Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive,FrequencyPattern)
						SELECT dbo.NewIDToNVCHAR128(NEWID()), ParentID, MedicineID, Dosage, DosageUnit, 
						TimeOfDay, [Time], Cibum, Purpose, Photo, @DateToday, 1, FrequencyPattern
						FROM dbo.MedicineSchedule 
						WHERE Id = @MedicineScheduleID
					end
					else
					begin
						UPDATE dbo.MedicineSchedule 
						SET LastXDate=DateAdd(day, floor(datediff(day, @StartDate, @DateToday)/@FrequencyDayNum)*@FrequencyDayNum, @StartDate)
						WHERE Id=@MedicineScheduleID
					end
				end
			end
		end
		else
		begin		
			IF @FrequencyPattern='Weekly' 
			begin
				set @PeriodStartDay =  DateAdd(day, -(datepart(weekday, @DateToday) + 5) % 7, @DateToday)
			end
			else --@FrequencyPattern='Monthly' 
			begin
				set @PeriodStartDay = dateadd(day, 1, eomonth(@DateToday, -1))
			end

			DECLARE FreqDateCursor CURSOR FOR
			SELECT value FROM STRING_SPLIT(@Frequency,',')
			OPEN FreqDateCursor 
			FETCH NEXT from FreqDateCursor INTO @cFreqDateString
			WHILE @@FETCH_STATUS = 0
			begin
				set @DateNext = DATEADD(DAY,CAST(@cFreqDateString as tinyint),@PeriodStartDay)
				if @DateNext >= @DateToday and @DateNext >= @StartDate
				begin
					INSERT INTO dbo.MedicineScheduleUpdate (Id,ParentId,MedicineId,
					Dosage,DosageUnit,TimeOfDay,[Time],Cibum,Purpose,Photo,[Date],IsActive,FrequencyPattern)
					SELECT dbo.NewIDToNVCHAR128(NEWID()), ParentID, MedicineID, Dosage, DosageUnit, 
					TimeOfDay, [Time], Cibum, Purpose, Photo, @DateNext , 1, FrequencyPattern
					FROM dbo.MedicineSchedule 
					WHERE Id = @MedicineScheduleID
				end 
				FETCH NEXT from FreqDateCursor INTO @cFreqDateString
			END 
			CLOSE FreqDateCursor
			DEALLOCATE FreqDateCursor
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

