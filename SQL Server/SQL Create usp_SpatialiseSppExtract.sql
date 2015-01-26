/*===========================================================================*\
  DataExtractor is a MapInfo tool to extract biodiversity information
  from SQL Server and MapInfo GIS layer for pre-defined spatial areas.
  
  Copyright © 2012-2013 Andy Foy Consulting
  
  This file is part of the MapInfo tool 'DataExtractor'.
  
  DataExtractor is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  
  DataExtractor is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with DataExtractor.  If not, see <http://www.gnu.org/licenses/>.
\*===========================================================================*/

USE [NBNData]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*===========================================================================*\
  Description:	Prepares an existing SQL table that contains spatial data
                so that it can be used 'spatially' by SQL Server and MapInfo

  Parameters:
	@Schema			The schema for the table to be spatialised.
	@Table			The name of the table to be spatialised.
	@XColumn		The name of the column containing the record eastings.
	@XMin			The minimum value for the eastings to be spatialised.
	@XMin			The maximum value for the eastings to be spatialised.
	@YColumn		The name of the column containing the record nothings.
	@XMin			The minimum value for the nothings to be spatialised.
	@XMin			The maximum value for the nothings to be spatialised.
	@SizeColumn		The name of the column containing the record precision.
	@SizeMin		The minimum value for the precision to be spatialised.
	@SizeMax		The maximum value for the precision to be spatialised.

  Created:	Nov 2012

  Last revision information:
    $Revision: 2 $
    $Date: 02/04/13 $
    $Author: Andy Foy $

\*===========================================================================*/

-- Drop the procedure if it already exists
if exists (select ROUTINE_NAME from INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA = 'dbo' and ROUTINE_NAME = 'usp_SpatialiseSppExtract')
	DROP PROCEDURE dbo.usp_SpatialiseSppExtract
GO

-- Create the stored procedure
CREATE PROCEDURE dbo.usp_SpatialiseSppExtract @Schema varchar(50), @Table varchar(50), @XColumn varchar(50), @XMin Int, @XMax Int, @YColumn varchar(50), @YMin Int, @YMax Int, @SizeColumn varchar(50), @SizeMin Int, @SizeMax Int
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @debug int
	Set @debug = 1

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Started.'

	DECLARE @sqlCommand varchar(2000)

	-- Add a new non-clustered index on the XColumn field if it doesn't already exists
	if not exists (select name from sys.indexes where name = 'IDX_' + @Table + '_' + @XColumn)
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding XColumn field index ...'

		Set @sqlCommand = 'CREATE INDEX IDX_' + @Table + '_' + @XColumn +
			' ON ' + @Schema + '.' + @Table +' (' + @XColumn+ ')'
		EXEC (@sqlcommand)
	END
	
	-- Add a new non-clustered index on the YColumn field if it doesn't already exists
	if not exists (select name from sys.indexes where name = 'IDX_' + @Table + '_' + @YColumn)
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding YColumn field index ...'

		Set @sqlCommand = 'CREATE INDEX IDX_' + @Table + '_' + @YColumn +
			' ON ' + @Schema + '.' + @Table +' (' + @YColumn+ ')'
		EXEC (@sqlcommand)
	END

	-- Add a new non-clustered index on the SizeColumn field if it doesn't already exists
	if not exists (select name from sys.indexes where name = 'IDX_' + @Table + '_' + @SizeColumn)
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding SizeColumn field index ...'

		Set @sqlCommand = 'CREATE INDEX IDX_' + @Table + '_' + @SizeColumn +
			' ON ' + @Schema + '.' + @Table +' (' + @SizeColumn+ ')'
		EXEC (@sqlcommand)
	END

	-- Add a new MapInfo style field if it doesn't already exists
	if not exists (select column_name from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = @Schema and TABLE_NAME = @Table and COLUMN_NAME = 'MI_STYLE')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding new MI_STYLE field ...'

		SET @sqlcommand = 'ALTER TABLE ' + @Schema + '.' + @Table +
			' ADD MI_STYLE VarChar(254)'
		EXEC (@sqlcommand)
	END

	-- Add a new primary key if it doesn't already exists
	if not exists (select column_name from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = @Schema and TABLE_NAME = @Table and COLUMN_NAME = 'MI_PRINX')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding new MI_PRINX field ...'

		SET @sqlcommand = 'ALTER TABLE ' + @Schema + '.' + @Table +
			' ADD MI_PRINX Int IDENTITY'
		EXEC (@sqlcommand)
	END

	-- Add a new geometry field if it doesn't already exists
	if not exists (select column_name from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA = @Schema and TABLE_NAME = @Table and COLUMN_NAME = 'SP_GEOMETRY')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding new SP_GEOMETRY field ...'

		SET @sqlcommand = 'ALTER TABLE ' + @Schema + '.' + @Table +
			' ADD SP_GEOMETRY Geometry'
		EXEC (@sqlcommand)
	END

	-- Add a new sequential index on the primary key if it doesn't already exists
	if not exists (select column_name from INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE where TABLE_SCHEMA = @Schema and TABLE_NAME = @Table and COLUMN_NAME = 'MI_PRINX' and CONSTRAINT_NAME = 'PK_' + @Table + '_MI_PRINX')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Adding new primary index ...'

		SET @sqlcommand = 'ALTER TABLE ' + @Schema + '.' + @Table +
			' ADD CONSTRAINT PK_' + @Table + '_MI_PRINX' +
			' PRIMARY KEY(MI_PRINX)'
		EXEC (@sqlcommand)
	END
	
	-- Drop the synonym for the table passed to the procedure if it already exists
	if exists (select name from sys.synonyms where name = 'Species_Temp')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Dropping table synonym ...'

		Set @sqlCommand = 'DROP SYNONYM Species_Temp'
		EXEC (@sqlcommand)
	END

	-- Create a synonym for the table passed to the procedure
	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Creating table synonym ...'
	Set @sqlCommand = 'CREATE SYNONYM Species_Temp' +
		' FOR ' + @Schema + '.' + @Table
	EXEC (@sqlcommand)

	-- Drop the view for the table (via the synonym) if it already exists
	if exists (select table_name from INFORMATION_SCHEMA.VIEWS where TABLE_NAME = 'Species_Temp_View')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Dropping table view ...'

		Set @sqlCommand = 'DROP VIEW Species_Temp_View'
		EXEC (@sqlcommand)
	END

	-- Create a view for the table (via the synonym)
	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Creating table view ...'

	Set @sqlCommand = 'CREATE VIEW Species_Temp_View' +
		' AS SELECT ' + @XColumn + ' As XCOORD,' +
		' ' + @YColumn + ' As YCOORD,' +
		' ' + @SizeColumn + ' As GRIDSIZE,' +
		' SP_GEOMETRY' +
		' FROM Species_Temp'
	EXEC (@sqlcommand)

	-- Drop the spatial index on the geometry field if it already exists
	if exists (select name from sys.indexes where name = 'SIndex_' + @Table + '_SP_Geometry')
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Dropping the spatial index ...'

		SET @sqlcommand = 'DROP INDEX SIndex_' + @Table + '_SP_Geometry ON ' + @Schema + '.' + @Table
		EXEC (@sqlcommand)
	END

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Updating valid geometries ...'

	-- Set the geometry for points based on the Xcolumn, YColumn and SizeColumn values
	UPDATE Species_Temp_View
		SET SP_GEOMETRY = geometry::STPointFromText('POINT(' +
		dbo.ufn_ReturnMidEastings(XCOORD,GRIDSIZE) + ' ' + dbo.ufn_ReturnMidNorthings(YCOORD,GRIDSIZE) + ')', 27700)
		WHERE XCOORD >= @XMin
		AND XCOORD <= @XMax
		AND YCOORD >= @YMin
		AND YCOORD <= @YMax
		AND GRIDSIZE >= @SizeMin
		AND GRIDSIZE <= @SizeMax
		AND GRIDSIZE <= 100

	-- Set the geometry for polygons based on the Xcolumn, YColumn and SizeColumn values
	UPDATE Species_Temp_View
		SET SP_GEOMETRY = geometry::STPolyFromText('POLYGON((' +
		dbo.ufn_ReturnLowerEastings(XCOORD,GRIDSIZE) + ' ' + dbo.ufn_ReturnLowerNorthings(YCOORD,GRIDSIZE) + ', ' +
		dbo.ufn_ReturnUpperEastings(XCOORD,GRIDSIZE) + ' ' + dbo.ufn_ReturnLowerNorthings(YCOORD,GRIDSIZE) + ', ' +
		dbo.ufn_ReturnUpperEastings(XCOORD,GRIDSIZE) + ' ' + dbo.ufn_ReturnUpperNorthings(YCOORD,GRIDSIZE) + ', ' +
		dbo.ufn_ReturnLowerEastings(XCOORD,GRIDSIZE) + ' ' + dbo.ufn_ReturnUpperNorthings(YCOORD,GRIDSIZE) + ', ' +
		dbo.ufn_ReturnLowerEastings(XCOORD,GRIDSIZE) + ' ' + dbo.ufn_ReturnLowerNorthings(YCOORD,GRIDSIZE) + '))', 27700)
		WHERE XCOORD >= @XMin
		AND XCOORD <= @XMax
		AND YCOORD >= @YMin
		AND YCOORD <= @YMax
		AND GRIDSIZE >= @SizeMin
		AND GRIDSIZE <= @SizeMax
		AND GRIDSIZE > 100

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Determining spatial extent ...'

	-- Calculate the geometric extent of the records (plus their precision)
	DECLARE
		@X1 int,
		@X2 int,
		@Y1 int,
		@Y2 int

	-- Retrieve the geometric extent values and store as variables
	SELECT  @X1 = MIN(XCOORD),
			@Y1 = MIN(YCOORD),
			@X2 = MAX(XCOORD) + MAX(GRIDSIZE),
			@Y2 = MAX(YCOORD) + MAX(GRIDSIZE)
	From Species_Temp_View
		WHERE XCOORD >= @XMin AND XCOORD <= @XMax AND YCOORD >= @YMin AND YCOORD <= @YMax AND GRIDSIZE >= @SizeMin AND GRIDSIZE <= @SizeMax

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Creating spatial index ...'

	-- Create the spatial index bounded by the geometric extent variables
	SET @sqlcommand = 'CREATE SPATIAL INDEX SIndex_' + @Table + '_SP_Geometry ON ' + @Schema + '.' + @Table + ' ( SP_Geometry )' + 
		' WITH ( ' +
		' BOUNDING_BOX = (XMIN=' + CAST(@X1 As varchar) + ', YMIN=' + CAST(@Y1 As varchar) + ', XMAX=' + CAST(@X2 AS varchar) + ', YMAX=' + CAST(@Y2 As varchar) + '),' +
		' GRIDS = (' +
			' LEVEL_1 = MEDIUM,' +
			' LEVEL_2 = MEDIUM,' +
			' LEVEL_3 = MEDIUM,' +
			' LEVEL_4 = MEDIUM),' +
		' CELLS_PER_OBJECT = 16' +
		')'
	EXEC (@sqlcommand)

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Dropping the synonym and view ...'

	-- Drop the table synonym
	DROP SYNONYM Species_Temp

	-- Drop the table view
	DROP View Species_Temp_View

	-- If the MapInfo MapCatalog exists then update it
	if exists (select TABLE_NAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA = 'MAPINFO' and TABLE_NAME = 'MAPINFO_MAPCATALOG')
	BEGIN

		-- Delete the MapInfo MapCatalog entry if it already exists
		if exists (select TABLENAME from [MAPINFO].[MAPINFO_MAPCATALOG] where TABLENAME = @Table)
		BEGIN
			If @debug = 1
				PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Deleting the MapInfo MapCatalog entry ...'
			SET @sqlcommand = 'DELETE FROM [MAPINFO].[MAPINFO_MAPCATALOG]' +
				' WHERE TABLENAME = ''' + @Table + ''''
			EXEC (@sqlcommand)
		END

		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Inserting the MapInfo MapCatalog entry ...'

		-- Adding table to MapInfo MapCatalog
		INSERT INTO [MAPINFO].[MAPINFO_MAPCATALOG]
			([SPATIALTYPE]
			,[TABLENAME]
			,[OWNERNAME]
			,[SPATIALCOLUMN]
			,[DB_X_LL]
			,[DB_Y_LL]
			,[DB_X_UR]
			,[DB_Y_UR]
			,[COORDINATESYSTEM]
			,[SYMBOL]
			,[XCOLUMNNAME]
			,[YCOLUMNNAME]
			,[RENDITIONTYPE]
			,[RENDITIONCOLUMN]
			,[RENDITIONTABLE]
			,[NUMBER_ROWS]
			,[VIEW_X_LL]
			,[VIEW_Y_LL]
			,[VIEW_X_UR]
			,[VIEW_Y_UR])
		 VALUES
			(17.2
			,@Table
			,@Schema
			,'SP_GEOMETRY'
			,@X1
			,@Y1
			,@X2
			,@Y2
			,'Earth Projection 8, 79, "m", -2, 49, 0.9996012717, 400000, -100000 Bounds (-7845061.1011, -15524202.1641) (8645061.1011, 4470074.53373)'
			,'Pen (1,2,0)  Brush (1,16777215,16777215)'
			,'NO_COLUMN'
			,'NO_COLUMN'
			,NULL
			,'MI_STYLE'
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL)

	END
	ELSE
	-- If the MapInfo MapCatalog doesn't exist then skip updating it
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'MapInfo MapCatalog not found - skipping update ...'
	END

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Ended.'

END
GO