/*===========================================================================*\
  DataExtractor is a MapInfo tool to extract biodiversity information
  from SQL Server and MapInfo GIS layer for pre-defined spatial areas.
  
  Copyright � 2012-2013, 2015 Andy Foy Consulting
  
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
  Description:	Select species records that intersect with the partner
                polygon(s) passed by the calling routine.

  Parameters:
	@Schema			The schema for the partner and species table.
	@PartnerTable	The name of the partner table used for selecting.
	@PartnerColumn	The name of the column containing the partner to be used.
	@AbbrevColumn	The name of the column containing the partner abbreviation.
	@SpeciesTable	The name of the table contain the species records.
	@UserId			The userid of the user executing the selection.

  Created:			Andy Foy - Nov 2012
  Last revised: 	Andy Foy - Sep 2015

 *****************  Version 3  *****************
 Author: Andy Foy		Date: 11/09/2015
 A. Remove hard-coded column names.
 B. Enable subsets to be non-spatial (i.e. have
	no geometry column.
 C. Lookup table column names and spatial variables
	from Spatial_Tables.

 *****************  Version 2  *****************
 Author: Andy Foy		Date: 08/06/2015
 A. Include userid as parameter to use in temporary SQL
	table name to enable concurrent use of tool.

 *****************  Version 1  *****************
 Author: Andy Foy		Date: 01/11/2012
 A. Initial version of code.

\*===========================================================================*/

-- Drop the procedure if it already exists
If EXISTS (SELECT ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_NAME = 'AFSelectSppRecords')
	DROP PROCEDURE dbo.AFSelectSppRecords
GO

-- Create the stored procedure
CREATE PROCEDURE dbo.AFSelectSppRecords
	@Schema varchar(50),
	@PartnerTable varchar(50),
	@PartnerColumn varchar(50),
	@Partner varchar(50),
	@Abbrev varchar(50),
	@SpeciesTable varchar(50),
	@UserId varchar(50)
AS
BEGIN

	SET NOCOUNT ON

	IF @UserId IS NULL
		SET @UserId = 'temp'

	DECLARE @debug int
	Set @debug = 0

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Started.'

	DECLARE @sqlCommand nvarchar(2000)
	DECLARE @params nvarchar(2000)

	DECLARE @TempTable varchar(50)
	SET @TempTable = @SpeciesTable + '_' + @UserId

	-- Drop the index on the sequential primary key of the temporary table if it already exists
	If EXISTS (SELECT column_name FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE WHERE TABLE_SCHEMA = @Schema AND TABLE_NAME = @TempTable AND COLUMN_NAME = 'MI_PRINX' AND CONSTRAINT_NAME = 'PK_MI_PRINX')
	BEGIN
		SET @sqlcommand = 'ALTER TABLE ' + @Schema + '.' + @TempTable +
			' DROP CONSTRAINT PK_MI_PRINX'
		EXEC (@sqlcommand)
	END
	
	-- Drop the temporary table if it already exists
	If EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = @Schema AND TABLE_NAME = @TempTable)
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Dropping temporary table ...'
		SET @sqlcommand = 'DROP TABLE ' + @Schema + '.' + @TempTable
		EXEC (@sqlcommand)
	END

	-- Lookup table column names and spatial variables from Spatial_Tables
	DECLARE @IsSpatial bit
	DECLARE @XColumn varchar(32), @YColumn varchar(32), @SizeColumn varchar(32), @SpatialColumn varchar(32)
	DECLARE @CoordSystem varchar(254)
	
	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Retrieving table spatial details ...'

	DECLARE @SpatialTable varchar(100)
	SET @SpatialTable ='Spatial_Tables'

	-- Retrieve the table column names and spatial variables
	SET @sqlcommand = 'SELECT @O1 = XColumn, ' +
							 '@O2 = YColumn, ' +
							 '@O3 = SizeColumn, ' +
							 '@O4 = IsSpatial, ' +
							 '@O5 = SpatialColumn, ' +
							 '@O6 = CoordSystem ' +
						'FROM ' + @Schema + '.' + @SpatialTable + ' ' +
						'WHERE TableName = ''' + @SpeciesTable + ''' AND OwnerName = ''' + @Schema + ''''

	SET @params =	'@O1 varchar(32) OUTPUT, ' +
					'@O2 varchar(32) OUTPUT, ' +
					'@O3 varchar(32) OUTPUT, ' +
					'@O4 bit OUTPUT, ' +
					'@O5 varchar(32) OUTPUT, ' +
					'@O6 varchar(254) OUTPUT'
		
	EXEC sp_executesql @sqlcommand, @params,
		@O1 = @XColumn OUTPUT, @O2 = @YColumn OUTPUT, @O3 = @SizeColumn OUTPUT, @O4 = @IsSpatial OUTPUT, 
		@O5 = @SpatialColumn OUTPUT, @O6 = @CoordSystem OUTPUT
		
	If @IsSpatial = 1
	BEGIN
		IF @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Table is spatial'
	END

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Performing intersect for partner = ' + @Partner + ' ...'

	-- Select the intersecting species records into the temporary table
	SET @sqlcommand = 
		'SELECT Spp.*' + 
		' INTO ' + @Schema + '.' + @TempTable +
		' FROM ' + @Schema + '.' + @SpeciesTable + ' As Spp, ' + @PartnerTable + ' As Poly' +
		' WHERE Poly.' + @PartnerColumn + ' = ''' + @Partner + '''' +
		' AND Spp.SP_GEOMETRY.STIntersects(Poly.SP_GEOMETRY) = 1' +
		' AND Poly.SP_GEOMETRY IS NOT NULL'
	EXEC (@sqlcommand)

	DECLARE @RecCnt Int
	Set @RecCnt = @@ROWCOUNT

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + Cast(@RecCnt As varchar) + ' records selected ...'

	-- If the MapInfo MapCatalog exists then update it
	IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'MAPINFO' AND TABLE_NAME = 'MAPINFO_MAPCATALOG')
	BEGIN

		-- Delete the MapInfo MapCatalog entry if it already exists
		IF EXISTS (SELECT TABLENAME FROM [MAPINFO].[MAPINFO_MAPCATALOG] WHERE TABLENAME = @TempTable)
		BEGIN
			IF @debug = 1
				PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Deleting the MapInfo MapCatalog entry ...'
			
			SET @sqlcommand = 'DELETE FROM [MAPINFO].[MAPINFO_MAPCATALOG]' +
				' WHERE TABLENAME = ''' + @TempTable + ''''
			EXEC (@sqlcommand)
		END

		-- Calculate the geometric extent of the records (plus their precision)
		DECLARE @X1 int, @X2 int, @Y1 int, @Y2 int

		SET @X1 = 0
		SET @X2 = 0
		SET @Y1 = 0
		SET @Y2 = 0

		-- Check if the table is spatial and the necessary columns are in the table (including a geometry column)
		IF  @IsSpatial = 1
		AND EXISTS(SELECT * FROM sys.columns WHERE Name = @XColumn AND Object_ID = Object_ID(@TempTable))
		AND EXISTS(SELECT * FROM sys.columns WHERE Name = @YColumn AND Object_ID = Object_ID(@TempTable))
		AND EXISTS(SELECT * FROM sys.columns WHERE Name = @SizeColumn AND Object_ID = Object_ID(@TempTable))
		AND EXISTS(SELECT * FROM sys.columns WHERE Name = @SpatialColumn AND Object_ID = Object_ID(@TempTable))
		AND EXISTS(SELECT * FROM sys.columns WHERE user_type_id = 129 AND Object_ID = Object_ID(@TempTable))
		BEGIN

			IF @debug = 1
				PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Determining spatial extent ...'

			-- Retrieve the geometric extent values and store as variables
			SET @sqlcommand = 'SELECT @xMin = MIN(' + @XColumn + '), ' +
									 '@yMin = MIN(' + @YColumn + '), ' +
									 '@xMax = MAX(' + @XColumn + ') + MAX(' + @SizeColumn + '), ' +
									 '@yMax = MAX(' + @YColumn + ') + MAX(' + @SizeColumn + ') ' +
									 'FROM ' + @Schema + '.' + @TempTable

			SET @params =	'@xMin int OUTPUT, ' +
							'@yMin int OUTPUT, ' +
							'@xMax int OUTPUT, ' +
							'@yMax int OUTPUT'
		
			EXEC sp_executesql @sqlcommand, @params,
				@xMin = @X1 OUTPUT, @yMin = @Y1 OUTPUT, @xMax = @X2 OUTPUT, @yMax = @Y2 OUTPUT
		
			If @debug = 1
				PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Inserting the MapInfo MapCatalog entry ...'

			---- Check if the spatial column is in the table
			--IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'SP_GEOMETRY' AND Object_ID = Object_ID(@TempTable))
			--BEGIN
			--	SET @sqlcommand = 'ALTER TABLE ' + @TempTable + ' ADD SP_GEOMETRY Geometry NULL'
			--	EXEC (@sqlcommand)
			--END

			-- Check if the rendition column is in the table
			IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'MI_STYLE' AND Object_ID = Object_ID(@TempTable))
			BEGIN
				SET @sqlcommand = 'ALTER TABLE ' + @TempTable + ' ADD MI_STYLE varchar(254) NULL'
				EXEC (@sqlcommand)
			END
			
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
				(17.3
				,@TempTable
				,@Schema
				,@SpatialColumn
				,@X1
				,@Y1
				,@X2
				,@Y2
				,@CoordSystem
				,'Pen (1,2,0)  Brush (1,16777215,16777215)'
				,NULL
				,NULL
				,NULL
				,'MI_STYLE'
				,NULL
				,@RecCnt
				,NULL
				,NULL
				,NULL
				,NULL)
		END
		ELSE
		BEGIN

			IF @debug = 1
				PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Table is non-spatial or required columns are missing.'

		END

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