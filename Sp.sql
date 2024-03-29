USE [SubstitutionDb]
GO
/****** Object:  StoredProcedure [dbo].[addDateMask]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addDateMask](
	@startingDate DATE,
	@yearRange INT,
	@columnName VARCHAR(MAX),
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX)
)
AS
BEGIN

		DECLARE @cnt INT = 1;
		DECLARE @totalRows INT;
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		DECLARE @maskedDate VARCHAR(MAX)
		DECLARE @currentDate VARCHAR(MAX)
			

		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		WHILE @cnt<=@totalRows
		BEGIN
		
			EXEC maskDate @startingDate=@startingDate,@yearRange=@yearRange,@maskedRandomDate=@maskedDate OUTPUT;
			SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+CAST(@maskedDate AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
			EXEC sys.sp_executesql @sql
		
			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[addDateMaskRange]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addDateMaskRange](
	@startingDate DATE,
	@range INT,
	@type VARCHAR(10),
	@columnName1 VARCHAR(MAX),
	@columnName2 VARCHAR(MAX),
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX)
)
AS
BEGIN

		DECLARE @cnt INT = 1;
		DECLARE @totalRows INT;
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		DECLARE @maskedStartDate DATE;
		DECLARE @maskedFinishDate DATE


		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		WHILE @cnt<=@totalRows
		BEGIN
		
			EXEC maskDateRange @startYear=@startingDate,@range=@range,@type=@type,@startDate=@maskedStartDate OUTPUT,@finishDate=@maskedFinishDate OUTPUT;

			SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName1+' = '''+CAST(@maskedStartDate AS VARCHAR)+''','+@columnName2+' = '''+CAST(@maskedFinishDate AS VARCHAR)+''''+' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
			EXEC sys.sp_executesql @sql
		
			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[addMaskBirthdate]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addMaskBirthdate](
	@columnName VARCHAR(MAX),
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX)
)
AS 
BEGIN
	
		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		CREATE TABLE #duplicateBirthdates(
			ID INT NOT NULL IDENTITY(1,1),
			DuplicateBirthdate VARCHAR(MAX),
			SubstituteBirthdate VARCHAR(MAX)
		);
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		SET @sql='INSERT INTO #duplicateBirthdates(DuplicateBirthdate) SELECT '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+
		' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+
		' GROUP BY '+@columnName+
		' HAVING COUNT(*)>1';
		EXEC sys.sp_executesql @sql;

		DECLARE @totalDuplicateRows INT = (SELECT COUNT(*) FROM #duplicateBirthdates );
		DECLARE @cntDuplicate INT=1;
		DECLARE @maskedBirthdate DATE;
		DECLARE @currentBirthdate DATE;

		
		WHILE @cntDuplicate <= @totalDuplicateRows
		BEGIN

			SET @currentBirthdate=(SELECT #duplicateBirthdates.DuplicateBirthdate FROM #duplicateBirthdates WHERE ID=@cntDuplicate);

			EXEC maskBirthdate @birthdate=@currentBirthdate,@maskedBirthdate=@maskedBirthdate OUTPUT;
	
			WHILE EXISTS (SELECT 1 FROM #duplicateBirthdates WHERE SubstituteBirthdate IN (@maskedBirthdate))
			BEGIN
				EXEC maskBirthdate @birthdate=@currentBirthdate,@maskedBirthdate=@maskedBirthdate OUTPUT;
			END

			UPDATE #duplicateBirthdates
			SET SubstituteBirthdate=@maskedBirthdate
			WHERE ID=@cntDuplicate
			SET @cntDuplicate=@cntDuplicate+1
		END
		
		WHILE @cnt <= @totalRows
		BEGIN

			DECLARE @substituteBirthdate VARCHAR(MAX)

			SET @sql=N'( SELECT @currentBirthdate= '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE ID='+ CAST(@cnt AS VARCHAR(MAX))+')';
			EXEC sys.sp_executesql @sql,N'@currentBirthdate DATE OUTPUT', @currentBirthdate=@currentBirthdate OUTPUT

			IF EXISTS (SELECT 1 FROM #duplicateBirthdates WHERE DuplicateBirthdate=@currentBirthdate)
			BEGIN

				SET @sql=N'( SELECT @substituteBirthdate=SubstituteBirthdate FROM #duplicateBirthdates WHERE DuplicateBirthdate = '''+CAST(@currentBirthdate AS VARCHAR)+''')';
				EXEC sys.sp_executesql @sql,N'@substituteBirthdate DATE OUTPUT',@substituteBirthdate=@substituteBirthdate OUTPUT

	
				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+CAST(@substituteBirthdate AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql;

			END; 
			ELSE
			BEGIN

				DECLARE @maskedSingleBirthdate VARCHAR(MAX);
				DECLARE @repeatBirthdayFlag INT=0;

				
				EXEC maskBirthdate @birthdate=@currentBirthdate,@maskedBirthdate=@maskedSingleBirthdate OUTPUT;


				SET @sql=N'SELECT @repeatValue=1 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE '+@columnName+' IN ('''+CAST(@maskedSingleBirthdate AS VARCHAR)+''')'
				EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatBirthdayFlag OUTPUT

				WHILE  (@repeatBirthdayFlag=1)
				BEGIN

					EXEC maskBirthdate @birthdate=@currentBirthdate,@maskedBirthdate=@maskedSingleBirthdate OUTPUT;
					SET @sql=N'SELECT @repeatValue=0 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+'WHERE'+@columnName+' NOT IN ('''+CAST(@maskedSingleBirthdate AS VARCHAR)+''')'
					EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatBirthdayFlag OUTPUT
				END

				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+CAST(@maskedSingleBirthdate AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql
			
			END
			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[addMaskImageHouse]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [dbo].[addMaskImageHouse](
	
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX),
	@columnName VARCHAR(MAX),
	@substituteDbName VARCHAR(MAX),
	@substituteSchemaName VARCHAR(MAX),
	@substituteTableName VARCHAR(MAX),
	@substituteColumnName VARCHAR(MAX),
	@type VARCHAR(MAX)
)
AS
BEGIN
	
		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		DECLARE @sql NVARCHAR(MAX);
		DECLARE @maskedImage VARBINARY(MAX)
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		WHILE @cnt<=@totalRows
		BEGIN
			EXEC maskImageHouse @type=@type,@maskedImage=@maskedImage OUTPUT
			SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = @maskedImage'+' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
			EXEC sys.sp_executesql @sql,N'@maskedImage VARBINARY(MAX)',@maskedImage
			SET @cnt=@cnt+1
		END
		

		/*SET @sql=N'UPDATE '+@substituteDbName+'.'+@substituteSchemaName+'.'+@substituteTableName+' SET '+@substituteColumnName+' = '''+CAST(@maskTimeMilliseconds AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
		EXEC sys.sp_executesql @sql*/

END
GO
/****** Object:  StoredProcedure [dbo].[addMaskNorwayFirstName]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addMaskNorwayFirstName](
	@columnName VARCHAR(MAX),
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX)
)
AS
BEGIN

		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		CREATE TABLE #duplicateNames(
			ID INT NOT NULL IDENTITY(1,1),
			DuplicateName VARCHAR(MAX),
			SubstituteName VARCHAR(MAX)
		);
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		SET @sql='INSERT INTO #duplicateNames(DuplicateName) SELECT '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+
		' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+
		' GROUP BY '+@columnName+
		' HAVING COUNT(*)>1';
		EXEC sys.sp_executesql @sql;

		DECLARE @totalDuplicateRows INT = (SELECT COUNT(*) FROM #duplicateNames );
		DECLARE @cntDuplicate INT=1;
		DECLARE @maskedName VARCHAR(MAX);
		DECLARE @currentName VARCHAR(MAX);
		DECLARE @gender VARCHAR(MAX);

		WHILE @cntDuplicate <= @totalDuplicateRows
		BEGIN

			SET @currentName=(SELECT #duplicateNames.DuplicateName FROM #duplicateNames WHERE ID=@cntDuplicate);

			IF EXISTS (SELECT 1 FROM norwayFirstNameUnisex WHERE FirstName LIKE '%'+@currentName+'%')
			BEGIN
				SET @gender='Unisex';
			END
			IF EXISTS (SELECT 1 FROM norwayFirstNameMale WHERE FirstName LIKE '%'+@currentName+'%')
			BEGIN
				SET @gender='Male';
			END
			IF EXISTS (SELECT 1 FROM norwayFirstNameFemale WHERE FirstName LIKE '%'+@currentName+'%')
			BEGIN
				SET @gender='Female';
			END

			EXEC maskNorwayFirstName @gender = @gender,@maskedFirstName=@maskedName OUTPUT;
	
			WHILE EXISTS (SELECT 1 FROM #duplicateNames WHERE SubstituteName IN (@maskedName))
			BEGIN
				EXEC maskNorwayFirstName @gender= @gender,@maskedFirstName=@maskedName OUTPUT;
			END

			UPDATE #duplicateNames
			SET SubstituteName=@maskedName
			WHERE ID=@cntDuplicate
			SET @cntDuplicate=@cntDuplicate+1
		END

		WHILE @cnt <= @totalRows
		BEGIN

			DECLARE @firstName VARCHAR(MAX);
			DECLARE @substituteName VARCHAR(MAX)

			SET @sql=N'( SELECT @currentName= '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE ID='+ CAST(@cnt AS VARCHAR(MAX))+')';
			EXEC sys.sp_executesql @sql,N'@currentName NVARCHAR(MAX) OUTPUT', @currentName=@firstName OUTPUT

			IF EXISTS (SELECT 1 FROM #duplicateNames WHERE DuplicateName=@firstName)
			BEGIN

				SET @sql=N'( SELECT @substituteName= SubstituteName FROM #duplicateNames WHERE DuplicateName = '''+@firstName+''')';
				EXEC sys.sp_executesql @sql,N'@substituteName NVARCHAR(MAX) OUTPUT',@substituteName=@substituteName OUTPUT

	
				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+@substituteName+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql;

			END; 
			ELSE
			BEGIN

				DECLARE @maskedFirstName VARCHAR(MAX);
				DECLARE @repeatNameFlag INT=0;

				SET @sql=N'( SELECT @currentName= '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE ID='+ CAST(@cnt AS VARCHAR(MAX))+')';
				EXEC sys.sp_executesql @sql,N'@currentName NVARCHAR(MAX) OUTPUT', @currentName=@firstName OUTPUT

				IF EXISTS (SELECT 1 FROM norwayFirstNameMale WHERE FirstName LIKE '%'+@firstName+'%')
				BEGIN
					SET @gender='Male';
				END
				IF EXISTS (SELECT 1 FROM norwayFirstNameFemale WHERE FirstName LIKE '%'+@firstName+'%')
				BEGIN
					SET @gender='Female';
				END
				IF EXISTS (SELECT 1 FROM norwayFirstNameUnisex WHERE FirstName LIKE '%'+@firstName+'%')
				BEGIN
					SET @gender='Unisex';
				END
				
				EXEC maskNorwayFirstName @gender = @gender,@maskedFirstName=@maskedFirstName OUTPUT;


				SET @sql=N'SELECT @repeatValue=1 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE '+@columnName+' IN ('''+@maskedFirstName+''')'
				EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatNameFlag OUTPUT

				WHILE  (@repeatNameFlag=1)
				BEGIN

					EXEC maskNorwayFirstName @gender = @gender,@maskedFirstName=@maskedFirstName OUTPUT;
					SET @sql=N'SELECT @repeatValue=0 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+'WHERE'+@columnName+' NOT IN ('''+@maskedFirstName+''')'
					EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatNameFlag OUTPUT
				END

				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+@maskedFirstName+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql
			
			END
			SET @cnt=@cnt+1
		END
	
END
GO
/****** Object:  StoredProcedure [dbo].[addMaskNorwayFullName]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addMaskNorwayFullName]
	@columnName VARCHAR(MAX),
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX),
	@surnameFirst INT
AS
BEGIN
		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		CREATE TABLE #duplicateNames(
			ID INT NOT NULL IDENTITY(1,1),
			DuplicateName VARCHAR(MAX),
			SubstituteName VARCHAR(MAX)
		);
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		SET @sql='INSERT INTO #duplicateNames(DuplicateName) SELECT '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+
		' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+
		' GROUP BY '+@columnName+
		' HAVING COUNT(*)>1';
		EXEC sys.sp_executesql @sql;

		DECLARE @totalDuplicateRows INT = (SELECT COUNT(*) FROM #duplicateNames );
		DECLARE @cntDuplicate INT=1;
		DECLARE @maskedName VARCHAR(MAX);
		DECLARE @currentName VARCHAR(MAX);
		DECLARE @firstName VARCHAR(MAX);
		DECLARE @gender VARCHAR(MAX);

		WHILE @cntDuplicate <= @totalDuplicateRows
		BEGIN

			SET @currentName=(SELECT #duplicateNames.DuplicateName FROM #duplicateNames WHERE ID=@cntDuplicate);

			IF(@surnameFirst=0)
			BEGIN
				SET @firstName = (SELECT TOP(1) Value FROM  string_split(@currentName,' '))
			END
			
			IF(@surnameFirst=1)
			BEGIN
				SET @firstName = (SELECT TOP(1) Value FROM  string_split(@currentName,' ') ORDER BY value DESC)
			END

			IF EXISTS (SELECT 1 FROM norwayFirstNameUnisex WHERE FirstName LIKE '%'+@firstName+'%')
			BEGIN
				SET @gender='Unisex';
			END
			IF EXISTS (SELECT 1 FROM norwayFirstNameMale WHERE FirstName LIKE '%'+@firstName+'%')
			BEGIN
				SET @gender='Male';
			END
			IF EXISTS (SELECT 1 FROM norwayFirstNameFemale WHERE FirstName LIKE '%'+@firstName+'%')
			BEGIN
				SET @gender='Female';
			END

			EXEC maskNorwayFullName @gender = @gender,@surnameFirst=@surnameFirst,@maskedName=@maskedName OUTPUT;
	
			WHILE EXISTS (SELECT 1 FROM #duplicateNames WHERE SubstituteName IN (@maskedName))
			BEGIN
				EXEC maskNorwayFullName @gender= @gender,@surnameFirst=@surnameFirst,@maskedName=@maskedName OUTPUT;
				SELECT @maskedName
			END

			UPDATE #duplicateNames
			SET SubstituteName=@maskedName
			WHERE ID=@cntDuplicate
			SET @cntDuplicate=@cntDuplicate+1
		END

		WHILE @cnt <= @totalRows
		BEGIN

			DECLARE @name VARCHAR(MAX);
			DECLARE @substituteName VARCHAR(MAX)

			SET @sql=N'( SELECT @currentName= '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE ID='+ CAST(@cnt AS VARCHAR(MAX))+')';
			EXEC sys.sp_executesql @sql,N'@currentName NVARCHAR(MAX) OUTPUT', @currentName=@name OUTPUT

			IF EXISTS (SELECT 1 FROM #duplicateNames WHERE DuplicateName=@name)
			BEGIN

				SET @sql=N'( SELECT @substituteName= SubstituteName FROM #duplicateNames WHERE DuplicateName = '''+@name+''')';
				EXEC sys.sp_executesql @sql,N'@substituteName NVARCHAR(MAX) OUTPUT',@substituteName=@substituteName OUTPUT

	
				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+@substituteName+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql;

			END; 
			ELSE
			BEGIN

				DECLARE @maskedSingleName VARCHAR(MAX);
				DECLARE @repeatNameFlag INT=0;

				SET @firstName = (SELECT TOP(1) Value FROM  string_split(@name,' '))

				IF EXISTS (SELECT 1 FROM norwayFirstNameUnisex WHERE FirstName LIKE '%'+@firstName+'%')
				BEGIN
					SET @gender='Unisex';
				END
				IF EXISTS (SELECT 1 FROM norwayFirstNameMale WHERE FirstName LIKE '%'+@firstName+'%')
				BEGIN
					SET @gender='Male';
				END
				IF EXISTS (SELECT 1 FROM norwayFirstNameFemale WHERE FirstName LIKE '%'+@firstName+'%')
				BEGIN
					SET @gender='Female';
				END
				
				EXEC maskNorwayFullName @gender = @gender,@surnameFirst=@surnameFirst,@maskedName=@maskedSingleName OUTPUT;


				SET @sql=N'SELECT @repeatValue=1 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE '+@columnName+' IN ('''+@maskedSingleName+''')'
				EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatNameFlag OUTPUT

				WHILE  (@repeatNameFlag=1)
				BEGIN

					EXEC maskNorwayFullName @gender = @gender,@surnameFirst=@surnameFirst,@maskedName=@maskedSingleName OUTPUT;
					SET @sql=N'SELECT @repeatValue=0 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+'WHERE'+@columnName+' NOT IN ('''+@maskedSingleName+''')'
					EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatNameFlag OUTPUT
				END

				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+@maskedSingleName+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql
			
			END
			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[addMaskNorwayLastName]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addMaskNorwayLastName](
	@columnName VARCHAR(MAX),
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX)
)
AS
BEGIN

		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		CREATE TABLE #duplicateNames(
			ID INT NOT NULL IDENTITY(1,1),
			DuplicateName VARCHAR(MAX),
			SubstituteName VARCHAR(MAX)
		);
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		SET @sql='INSERT INTO #duplicateNames(DuplicateName) SELECT '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+
		' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+
		' GROUP BY '+@columnName+
		' HAVING COUNT(*)>1';
		EXEC sys.sp_executesql @sql;

		DECLARE @totalDuplicateRows INT = (SELECT COUNT(*) FROM #duplicateNames );
		DECLARE @cntDuplicate INT=1;
		DECLARE @maskedName VARCHAR(MAX);
		DECLARE @currentName VARCHAR(MAX);

		WHILE @cntDuplicate <= @totalDuplicateRows
		BEGIN

			SET @currentName=(SELECT #duplicateNames.DuplicateName FROM #duplicateNames WHERE ID=@cntDuplicate);

			EXEC maskNorwayLastName @maskedLastName=@maskedName OUTPUT;
	
			WHILE EXISTS (SELECT 1 FROM #duplicateNames WHERE SubstituteName IN (@maskedName))
			BEGIN
				EXEC maskNorwayLastName @maskedLastName=@maskedName OUTPUT;
			END

			UPDATE #duplicateNames
			SET SubstituteName=@maskedName
			WHERE ID=@cntDuplicate
			SET @cntDuplicate=@cntDuplicate+1
		END

		WHILE @cnt <= @totalRows
		BEGIN

			DECLARE @lastName VARCHAR(MAX);
			DECLARE @substituteName VARCHAR(MAX)

			SET @sql=N'( SELECT @currentName= '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE ID='+ CAST(@cnt AS VARCHAR(MAX))+')';
			EXEC sys.sp_executesql @sql,N'@currentName NVARCHAR(MAX) OUTPUT', @currentName=@lastName OUTPUT

			IF EXISTS (SELECT 1 FROM #duplicateNames WHERE DuplicateName=@lastName)
			BEGIN

				SET @sql=N'( SELECT @substituteName= SubstituteName FROM #duplicateNames WHERE DuplicateName = '''+@lastName+''')';
				EXEC sys.sp_executesql @sql,N'@substituteName NVARCHAR(MAX) OUTPUT',@substituteName=@substituteName OUTPUT

	
				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+@substituteName+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql;

			END; 
			ELSE
			BEGIN

				DECLARE @maskedLastName VARCHAR(MAX);
				DECLARE @repeatNameFlag INT=0;

				SET @sql=N'( SELECT @currentName= '+@dbName+'.'+@schemaName+'.'+@tableName+'.'+@columnName+' FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE ID='+ CAST(@cnt AS VARCHAR(MAX))+')';
				EXEC sys.sp_executesql @sql,N'@currentName NVARCHAR(MAX) OUTPUT', @currentName=@lastName OUTPUT


				EXEC maskNorwayLastName @maskedLastName=@maskedLastName OUTPUT;


				SET @sql=N'SELECT @repeatValue=1 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+' WHERE '+@columnName+' IN ('''+@maskedLastName+''')'
				EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatNameFlag OUTPUT

				WHILE  (@repeatNameFlag=1)
				BEGIN

					EXEC maskNorwayLastName @maskedLastName=@maskedLastName OUTPUT;
					SET @sql=N'SELECT @repeatValue=0 FROM '+@dbName+'.'+@schemaName+'.'+@tableName+'WHERE'+@columnName+' NOT IN ('''+@maskedLastName+''')'
					EXEC sys.sp_executesql @sql,N'@repeatValue INT OUTPUT',@repeatValue=@repeatNameFlag OUTPUT
				END

				SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+@maskedLastName+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
				EXEC sys.sp_executesql @sql
			
			END
			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[addMaskTime]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addMaskTime](
	
	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX),
	@columnName VARCHAR(MAX),
	@substituteDbName VARCHAR(MAX),
	@substituteSchemaName VARCHAR(MAX),
	@substituteTableName VARCHAR(MAX),
	@substituteColumnName VARCHAR(MAX),
	@maskTillMillisecondFlag INT
)
AS
BEGIN

		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		IF(@maskTillMillisecondFlag=0)
		BEGIN
			DECLARE @maskTimeSeconds TIME(0);
		END
		ELSE
		BEGIN
			DECLARE @maskTimeMilliseconds TIME(7);
		END

		WHILE @cnt <= @totalRows
		BEGIN

				IF(@maskTillMillisecondFlag=0)
				BEGIN
					EXEC maskTimeSeconds @time=@maskTimeSeconds OUTPUT

					SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+CAST(@maskTimeSeconds AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql

					/*SET @sql=N'UPDATE '+@substituteDbName+'.'+@substituteSchemaName+'.'+@substituteTableName+' SET '+@substituteColumnName+' = '''+CAST(@maskTimeSeconds AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql*/
				END
				ELSE
				BEGIN
					EXEC maskTimeMiliseconds @time=@maskTimeMilliseconds OUTPUT

					SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName+' = '''+CAST(@maskTimeMilliseconds AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql

					/*SET @sql=N'UPDATE '+@substituteDbName+'.'+@substituteSchemaName+'.'+@substituteTableName+' SET '+@substituteColumnName+' = '''+CAST(@maskTimeMilliseconds AS VARCHAR)+''' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql*/
				END

			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[addMaskTimeRange]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[addMaskTimeRange](

	@dbName VARCHAR(MAX),
	@schemaName VARCHAR(MAX),
	@tableName VARCHAR(MAX),
	@columnName1 VARCHAR(MAX),
	@columnName2 VARCHAR(MAX),
	@substituteDbName VARCHAR(MAX),
	@substituteSchemaName VARCHAR(MAX),
	@substituteTableName VARCHAR(MAX),
	@substituteColumnName1 VARCHAR(MAX),
	@substituteColumnName2 VARCHAR(MAX),
	@maskTillMillisecondFlag INT,
	@range INT,
	@type VARCHAR(10)
)
AS
BEGIN
		DECLARE @cnt INT=1;
		DECLARE @totalRows INT=0;
		DECLARE @sql NVARCHAR(MAX);
		CREATE Table #count(value INT);
		
		SET @sql='INSERT INTO #count(value) SELECT COUNT(*) FROM '+@dbName+'.'+@schemaName+'.'+@tableName;
		EXEC sys.sp_executesql @sql

		SET @totalRows= (SELECT TOP(1) value FROM #count)
		DROP TABLE #count;

		IF(@maskTillMillisecondFlag=0)
		BEGIN
			DECLARE @maskStartTimeSeconds TIME(0);
			DECLARE @maskFinishTimeSeconds TIME(0);
		END
		ELSE
		BEGIN
			DECLARE @maskStartTimeMilliseconds TIME(7);
			DECLARE @maskFinishTimeMilliseconds TIME(7);
		END

		WHILE @cnt <= @totalRows
		BEGIN

				IF(@maskTillMillisecondFlag=0)
				BEGIN
					EXEC maskTimeRangeSeconds @range=@range,@type=@type,@maskedStartTimeSeconds=@maskStartTimeSeconds  OUTPUT,@maskedFinishTimeSeconds=@maskFinishTimeSeconds  OUTPUT

					SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName1+' = '''+CAST(@maskStartTimeSeconds AS VARCHAR)+''','+@columnName2+' = '''+CAST(@maskFinishTimeSeconds AS VARCHAR)+''''+' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql

					/*SET @sql=N'UPDATE '+@substituteDbName+'.'+@substituteSchemaName+'.'+@substituteTableName+' SET '+@substituteColumnName1+' = '''+CAST(@maskStartTimeSeconds AS VARCHAR)+''','+@substituteColumnName2+' = '''+CAST(@maskFinishTimeSeconds AS VARCHAR)+''''+' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql*/
				END
				ELSE
				BEGIN
					EXEC maskTimeRangeMilliseconds  @range=@range,@type=@type,@maskedStartTimeMilliseconds=@maskStartTimeMilliseconds  OUTPUT,@maskedFinishTimeMilliseconds=@maskFinishTimeMilliseconds  OUTPUT

					SET @sql=N'UPDATE '+@dbName+'.'+@schemaName+'.'+@tableName+' SET '+@columnName1+' = '''+CAST(@maskStartTimeMilliseconds AS VARCHAR)+''','+@columnName2+' = '''+CAST(@maskFinishTimeMilliseconds AS VARCHAR)+''''+'WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql

					/*SET @sql=N'UPDATE '+@substituteDbName+'.'+@substituteSchemaName+'.'+@substituteTableName+' SET '+@substituteColumnName1+' = '''+CAST(@maskStartTimeMilliseconds AS VARCHAR)+''','+@substituteColumnName2+' = '''+CAST(@maskFinishTimeMilliseconds AS VARCHAR)+''''+' WHERE ID ='+CAST(@cnt AS VARCHAR(MAX));
					EXEC sys.sp_executesql @sql*/
				END

			SET @cnt=@cnt+1
		END
END
GO
/****** Object:  StoredProcedure [dbo].[maskBirthdate]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskBirthdate]
	@birthdate DATE,
	@maskedBirthdate DATE OUTPUT
AS
BEGIN

	DECLARE @maskedYear INT;
	DECLARE @maskedMonth INT=(SELECT FLOOR(RAND()*(13-1)+1));
	DECLARE @maskedDate INT;
	DECLARE @randomValueAddForBirthyear INT = (SELECT FLOOR(RAND()*(4-1)+1));
	DECLARE @valueOfSignNegative INT=(SELECT FLOOR(RAND()*(7-1)+1));
	DECLARE @newBirthdate VARCHAR(MAX);

	IF (@valueOfSignNegative<3)
	BEGIN
		SET @randomValueAddForBirthyear = - @randomValueAddForBirthyear
		SET @newBirthdate= (SELECT DATEADD(YEAR,@randomValueAddForBirthyear,@birthdate))
	END
	ElSE
	BEGIN
		SET @newBirthdate= (SELECT DATEADD(YEAR,@randomValueAddForBirthyear,@birthdate))
	END

	SET @maskedYear=(SELECT YEAR(@newBirthdate))
	
	IF (@maskedMonth IN (1,3,5,7,8,10,11) )
	BEGIN
		SET @maskedDate= (SELECT FLOOR(RAND()*(32-1)+1));
	END
	ELSE IF ( @maskedMonth =2 )
	BEGIN
		SET @maskedDate =(SELECT FLOOR(RAND()*(29-1)+1));
	END
	ELSE
	BEGIN
		SET @maskedDate=(SELECT FLOOR(RAND()*(31-1)+1));
	END

	SET @newBirthdate= CAST(@maskedYear AS VARCHAR(MAX))+'-'+CAST(@maskedMonth AS varchar(MAX))+'-'+CAST(@maskedDate AS varchar(MAX));
	SET @maskedBirthdate= CAST(@newBirthdate AS DATE)
	
END
GO
/****** Object:  StoredProcedure [dbo].[maskDate]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskDate](
	@startingDate DATE,
	@yearRange INT,
	@maskedRandomDate DATE OUTPUT
)
AS
BEGIN

	DECLARE @randomDate DATE = DATEADD(DAY , ABS(CHECKSUM(NEWID()) % (365*@yearRange)),@startingDate);
	SET  @maskedRandomDate = (SELECT CONVERT(DATE,@randomDate,23))

END
GO
/****** Object:  StoredProcedure [dbo].[maskDateRange]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskDateRange](
	@startYear DATE,
	@range INT,
	@type VARCHAR(10),
	@startDate DATE OUTPUT,
	@finishDate DATE OUTPUT
)
AS 
BEGIN
	DECLARE @cnt INT = 1;
	DECLARE @totalRows INT=(SELECT COUNT(*) FROM test.dbo.dateTest);

	IF(@type NOT IN( 'year','month','day'))
		BEGIN
			RAISERROR('Invalid range type',18,0)
			RETURN
		END

	IF (@type IS NULL)
		BEGIN
			RAISERROR('Range type should not be null',18,0)
			RETURN
		END

	DECLARE @randomStartDate DATE = DATEADD(DAY , ABS(CHECKSUM(NEWID()) % 730),@startYear);
	SET @startDate=@randomStartDate;

	IF @type='year'
	BEGIN
		DECLARE @finishDateYear DATE =DATEADD(YEAR,@range,@randomStartDate);
		SET @finishDate=@finishDateYear
			
	END
	IF @type='month'
	BEGIN
		DECLARE @finishDateMonth DATE =DATEADD(MONTH,@range,@randomStartDate);
		SET @finishDate=@finishDateMonth
			
	END
	IF @type='day'
	BEGIN
		DECLARE @finishDateDay DATE =DATEADD(DAY,@range,@randomStartDate);
		SET @finishDate=@finishDateDay
			
	END

	
	
	
	
END
GO
/****** Object:  StoredProcedure [dbo].[maskImageHouse]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskImageHouse](
	@type VARCHAR(MAX),
	@maskedImage VARBINARY(MAX) OUTPUT
)
AS
BEGIN
	IF(@type IN ('house'))
	BEGIN
		DECLARE @totalImageCount INT=(SELECT COUNT(*) FROM SubstitutionDb.dbo.imageSubstitutionHouse)
		DECLARE @randomIndex INT=(SELECT FLOOR(RAND()*(@totalImageCount-1)+1));
		SET @maskedImage = (SELECT Houses FROM SubstitutionDb.dbo.imageSubstitutionHouse WHERE ID=@randomIndex)
	END
END
GO
/****** Object:  StoredProcedure [dbo].[maskNorwayFirstName]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskNorwayFirstName](
	@gender VARCHAR(10),
	@maskedFirstName VARCHAR(MAX) OUTPUT
)
AS
BEGIN
	
	DECLARE @firstNameIndex INT; 
	DECLARE @maskFirstName VARCHAR(MAX);

	IF(@gender='Male')
		BEGIN
			SET @firstNameIndex =(SELECT FLOOR(RAND()*(7732-1)+1));
			SET @maskFirstName = (SELECT [FirstName] FROM SubstitutionDb.dbo.norwayFirstNameMale WHERE ID = @firstNameIndex);
		END
	IF(@gender='Female')
		BEGIN
			SET @firstNameIndex = (SELECT FLOOR(RAND()*(7144-1)+1));
			SET @maskFirstName = (SELECT [FirstName] FROM SubstitutionDb.dbo.norwayFirstNameFeMale WHERE ID = @firstNameIndex);
		END
	IF(@gender='Unisex')
		BEGIN
			SET @firstNameIndex = (SELECT FLOOR(RAND()*(744-1)+1));
			SET @maskFirstName = (SELECT [FirstName] FROM SubstitutionDb.dbo.norwayFirstNameFeMale WHERE ID = @firstNameIndex);
		END

	SET @maskedFirstName= @maskFirstName;

END
GO
/****** Object:  StoredProcedure [dbo].[maskNorwayFullName]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskNorwayFullName]
	@gender VARCHAR(10),
	@surnameFirst INT=0,
	@maskedName VARCHAR(MAX) OUTPUT
AS
BEGIN

	DECLARE @firstNameIndex INT; 
	DECLARE @lastNameIndex INT;
	DECLARE @maskLastName VARCHAR(MAX);
	DECLARE @maskFirstName VARCHAR(MAX);

	IF(@gender='Male')
		BEGIN
			SET @firstNameIndex =(SELECT FLOOR(RAND()*(7732-1)+1));
			SET @maskFirstName = (SELECT [FirstName] FROM SubstitutionDb.dbo.norwayFirstNameMale WHERE ID = @firstNameIndex);
		END
	IF(@gender='Female')
		BEGIN
			SET @firstNameIndex = (SELECT FLOOR(RAND()*(7144-1)+1));
			SET @maskFirstName = (SELECT [FirstName] FROM SubstitutionDb.dbo.norwayFirstNameFeMale WHERE ID = @firstNameIndex);
		END
	IF(@gender='Unisex')
		BEGIN
			SET @firstNameIndex = (SELECT FLOOR(RAND()*(744-1)+1));
			SET @maskFirstName = (SELECT [FirstName] FROM SubstitutionDb.dbo.norwayFirstNameFeMale WHERE ID = @firstNameIndex);
		END

	SET @lastNameIndex = (SELECT FLOOR(RAND()*(789-1)+1));
	SET @maskLastName = (SELECT [LastName] FROM SubstitutionDb.dbo.norwayLastNameSubstitution WHERE ID = @lastNameIndex);

	IF(@surnameFirst=0)
	BEGIN
		SET @maskedName= @maskFirstName+' '+@maskLastName;
	END
	ELSE IF(@surnameFirst=1)
	BEGIN
		SET @maskedName= +@maskLastName+' '+@maskFirstName;
	END
END;
GO
/****** Object:  StoredProcedure [dbo].[maskNorwayLastName]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskNorwayLastName](
	@maskedLastName VARCHAR(MAX) OUTPUT
)
AS
BEGIN
	
	DECLARE @lastNameIndex INT; 
	DECLARE @maskLastName VARCHAR(MAX);

	SET @lastNameIndex = (SELECT FLOOR(RAND()*(789-1)+1));
	SET @maskLastName = (SELECT [LastName] FROM SubstitutionDb.dbo.norwayLastNameSubstitution WHERE ID = @lastNameIndex);

	SET @maskedLastName=@maskLastName;

END
GO
/****** Object:  StoredProcedure [dbo].[maskTimeMiliseconds]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskTimeMiliseconds](
	@time TIME(7) OUTPUT
)
AS
BEGIN

	DECLARE @cnt INT =1;
	DECLARE @testTime VARCHAR(MAX);
	DECLARE @totalRows INT =(SELECT COUNT(*) FROM test.dbo.timeTest);

	DECLARE @hour VARCHAR(10)=CAST(FLOOR(RAND()*23) AS VARCHAR(10));
	DECLARE @min VARCHAR(10)=CAST(FLOOR(RAND()*59) AS VARCHAR(10));
	DECLARE @seconds VARCHAR(10)=CAST(FLOOR(RAND()*59) AS VARCHAR(10));
	DECLARE @miliSeconds VARCHAR(10)=CAST(FLOOR(RAND()*1000) AS VARCHAR(10));


	SET @time= CAST(@hour+':'+@min+':'+@seconds+':'+@miliSeconds AS TIME(7))
	
END
GO
/****** Object:  StoredProcedure [dbo].[maskTimeRangeMilliseconds]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskTimeRangeMilliseconds](
	@range INT,
	@type VARCHAR(10),
	@maskedStartTimeMilliseconds TIME(7) OUTPUT,
	@maskedFinishTimeMilliSeconds TIME(7) OUTPUT
)
AS
BEGIN
	DECLARE @cnt INT =1;
	DECLARE @totalRows INT =(SELECT COUNT(*) FROM test.dbo.timeTest);
	DECLARE @hour VARCHAR(10)=CAST(FLOOR(RAND()*24) AS VARCHAR(10));
	DECLARE @min VARCHAR(10)=CAST(FLOOR(RAND()*60) AS VARCHAR(10));
	DECLARE @second VARCHAR(10)=CAST(FLOOR(RAND()*60) AS VARCHAR(10));
	DECLARE @millisecond VARCHAR(10)=CAST(FLOOR(RAND()*60) AS VARCHAR(10));

	DECLARE @startTime TIME=CAST(@hour+':'+@min+':'+@second+':'+@millisecond AS TIME(7))

	SET @maskedStartTimeMilliseconds=@startTime;

	IF(@type NOT IN ('hour','minute','second','millisecond'))
		BEGIN
			RAISERROR('Invalid range type',18,0)
			RETURN
		END

	IF (@type IS NULL)
		BEGIN
			RAISERROR('Range type should not be null',18,0)
			RETURN
		END

	
		IF @type='minute'
		BEGIN
			DECLARE @finishTimeMin TIME(7) = DATEADD(MINUTE,@range,@startTime);
			SET @maskedFinishTimeMilliSeconds=@finishTimeMin
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeMin
			WHERE @cnt=ID*/
		END
		IF @type='hour'
		BEGIN
			DECLARE @finishTimeHour TIME(7) = DATEADD(HOUR,@range,@startTime);
			SET @maskedFinishTimeMilliSeconds= @finishTimeHour
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeHour
			WHERE @cnt=ID*/
		END
		IF @type='second'
		BEGIN
			DECLARE @finishTimeSecond TIME(7) = DATEADD(SECOND,@range,@startTime);
			SET @maskedFinishTimeMilliSeconds= @finishTimeSecond
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeHour
			WHERE @cnt=ID*/
		END
		IF @type='millisecond'
		BEGIN
			DECLARE @finishTimeMillisecond TIME(7) = DATEADD(MILLISECOND,@range,@startTime);
			SET @maskedFinishTimeMilliSeconds= @finishTimeMillisecond
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeHour
			WHERE @cnt=ID*/
		END

	/*WHILE @cnt <= @totalRows
	BEGIN
		
		
		
		UPDATE test.dbo.timeTest
		SET startTime=@startTime
		WHERE @cnt=ID
		
		SET @cnt=@cnt+1
	END*/
END
GO
/****** Object:  StoredProcedure [dbo].[maskTimeRangeSeconds]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskTimeRangeSeconds](
	@range INT,
	@type VARCHAR(10),
	@maskedStartTimeSeconds TIME(0) OUTPUT,
	@maskedFinishTimeSeconds TIME(0) OUTPUT
)
AS
BEGIN
	DECLARE @cnt INT =1;
	DECLARE @totalRows INT =(SELECT COUNT(*) FROM test.dbo.timeTest);
	DECLARE @hour VARCHAR(10)=CAST(FLOOR(RAND()*24) AS VARCHAR(10));
	DECLARE @min VARCHAR(10)=CAST(FLOOR(RAND()*60) AS VARCHAR(10));
	DECLARE @seconds VARCHAR(10)=CAST(FLOOR(RAND()*60) AS VARCHAR(10));
	DECLARE @startTime TIME=CAST(@hour+':'+@min+':'+@seconds AS TIME(0))

	SET @maskedStartTimeSeconds=@startTime;

	IF(@type NOT IN ('hour','minute','second'))
		BEGIN
			RAISERROR('Invalid range type',18,0)
			RETURN
		END

	IF (@type IS NULL)
		BEGIN
			RAISERROR('Range type should not be null',18,0)
			RETURN
		END

	
		IF @type='minute'
		BEGIN
			DECLARE @finishTimeMin TIME(0) = DATEADD(MINUTE,@range,@startTime);
			SET @maskedFinishTimeSeconds=@finishTimeMin
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeMin
			WHERE @cnt=ID*/
		END
		IF @type='hour'
		BEGIN
			DECLARE @finishTimeHour TIME(0) = DATEADD(HOUR,@range,@startTime);
			SET @maskedFinishTimeSeconds= @finishTimeHour
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeHour
			WHERE @cnt=ID*/
		END
		IF @type='seconds'
		BEGIN
			DECLARE @finishTimeSecond TIME(0) = DATEADD(SECOND,@range,@startTime);
			SET @maskedFinishTimeSeconds= @finishTimeSecond
			/*UPDATE test.dbo.timeTest
			SET finishTime=@finishTimeHour
			WHERE @cnt=ID*/
		END

	/*WHILE @cnt <= @totalRows
	BEGIN
		
		
		
		UPDATE test.dbo.timeTest
		SET startTime=@startTime
		WHERE @cnt=ID
		
		SET @cnt=@cnt+1
	END*/
END
GO
/****** Object:  StoredProcedure [dbo].[maskTimeSeconds]    Script Date: 9/8/2019 9:33:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[maskTimeSeconds](
@time TIME(0) OUTPUT
)
AS
BEGIN
	DECLARE @cnt INT =1;
	DECLARE @testTime VARCHAR(MAX);
	DECLARE @totalRows INT =(SELECT COUNT(*) FROM test.dbo.timeTest);

	DECLARE @hour VARCHAR(10)=CAST(FLOOR(RAND()*23) AS VARCHAR(10));
	DECLARE @min VARCHAR(10)=CAST(FLOOR(RAND()*59) AS VARCHAR(10));
	DECLARE @seconds VARCHAR(10)=CAST(FLOOR(RAND()*59) AS VARCHAR(10));

	SET @time= CAST(@hour+':'+@min+':'+@seconds AS TIME(0))
	
	
	
	
	/*WHILE @cnt <= @totalRows
	BEGIN
		
		UPDATE test.dbo.timeTest
		SET Time= CAST(@hour+':'+@min AS TIME)
		WHERE ID=@cnt;
		SET @cnt=@cnt+1
	END*/

	SELECT @testTime

END
GO
