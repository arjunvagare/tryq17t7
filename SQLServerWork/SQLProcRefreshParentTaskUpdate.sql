
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

			INSERT INTO dbo.ParentTaskUpdate (Id,ParentId,ParentTaskId,
				[Date],[Name],[Type],[Order],Icon,Frequency,TimeOfDay, ParentStatus, IsActive)
				SELECT dbo.NewIDToNVCHAR128(NEWID()),pt.ParentId,pt.Id,
				@DateToday,pt.[Name],pt.[Type],pt.[Order],pt.Icon,pt.Frequency,pt.TimeOfDay,0,1 
				FROM dbo.ParentTask pt, dbo.Parent p
				WHERE  pt.ParentId = p.Id
				AND pt.Frequency = @Frequency
--				AND p.TimeZone = @TimeZone
		END TRY
		BEGIN CATCH
			ROLLBACK
			SET @errFlag = 1
			SET @errMessage = 'ERROR NUMBER: '+ CONVERT(nvarchar(10), ERROR_NUMBER()) +CHAR(13)+'ERROR MESSAGE: ' + ERROR_MESSAGE() 
		END CATCH
	COMMIT
END
GO

