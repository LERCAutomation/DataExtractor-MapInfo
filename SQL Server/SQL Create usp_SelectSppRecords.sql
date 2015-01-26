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
  Description:	Select species records that intersect with the partner
                polygon(s) passed by the calling routine.

  Parameters:
	@Schema			The schema for the partner and species table.
	@PartnerTable	The name of the partner table used for selecting.
	@PartnerColumn	The name of the column containing the partner to be used.
	@AbbrevColumn	The name of the column containing the partner abbreviation.
	@SpeciesTable	The name of the table contain the species records.

  Created:	Nov 2012

  Last revision information:
    $Revision: 2 $
    $Date: 02/04/13 $
    $Author: Andy Foy $

\*===========================================================================*/

-- Drop the procedure if it already exists
if exists (select ROUTINE_NAME from INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA = 'dbo' and ROUTINE_NAME = 'usp_SelectSppRecords')
	DROP PROCEDURE dbo.usp_SelectSppRecords
GO

-- Create the stored procedure
CREATE PROCEDURE dbo.usp_SelectSppRecords @Schema varchar(50), @PartnerTable varchar(50), @PartnerColumn varchar(50), @Partner varchar(50), @Abbrev varchar(50), @SpeciesTable varchar(50)
AS
BEGIN

	SET NOCOUNT ON

	DECLARE @debug int
	Set @debug = 0

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Started.'

	DECLARE @sqlCommand nvarchar(2000)

	DECLARE @TempTable varchar(50)
	SET @TempTable = @SpeciesTable + '_temp'

	-- Drop the index on the sequential primary key of the temporary table if it already exists
	if exists (select column_name from INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE where TABLE_SCHEMA = @Schema and TABLE_NAME = @TempTable and COLUMN_NAME = 'MI_PRINX' and CONSTRAINT_NAME = 'PK_' + @TempTable + '_MI_PRINX')
	BEGIN
		SET @sqlcommand = 'ALTER TABLE ' + @Schema + '.' + @TempTable +
			' DROP CONSTRAINT PK_' + @TempTable + '_MI_PRINX'
		EXEC (@sqlcommand)
	END
	
	-- Drop the temporary table if it already exists
	if exists (select TABLE_NAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA = @Schema and TABLE_NAME = @TempTable)
	BEGIN
		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Dropping temporary table ...'
		SET @sqlcommand = 'DROP TABLE ' + @Schema + '.' + @TempTable
		EXEC (@sqlcommand)
	END

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Creating temporary table ...'

	-- Create a temporary table for the selected species records
	SET @sqlcommand = 'SELECT TOP(0) ' +
		'SPP_NAME ' +
		',LATIN_NAME ' +
		',RECORD_TAXON_CLASS ' +
		',TAXONOMIC_GROUP ' +
		',DATE_START ' +
		',DATE_END ' +
		',DATE_RANGE ' +
		',RECORDYEAR ' +
		',RECORDER ' +
		',DETERMINER ' +
		',VERIFICATION ' +
		',GRIDREF ' +
		',EASTINGS ' +
		',NORTHINGS ' +
      	',GRPRECISION ' +
		',QUALIFIER ' +
		',COMMENTS ' +
		',BREEDING_STATUS ' +
		',STATUS_PLANNING ' +
		',STATUS_OTHER ' +
		',STATUS_LISI ' +
		',CONFIDENTIAL ' +
		',SENSITIVE ' +
		',SORTORDER ' +
		',R6SURVEY ' +
		',RECORDERID_TOCC ' +
		',NEG_RECORD ' +
		',RECORDERID_TVK ' +
		',RECORDERID_TLIK ' +
		',RECORDERID_SYK ' +
		',RECORDERID_SPK ' +
		',RECDIC ' +
		',SP_GEOMETRY ' +
		'INTO ' + @Schema + '.' + @TempTable + ' ' +
		'FROM ' + @Schema + '.' + @SpeciesTable
	EXEC (@sqlcommand)

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Performing intersect for Partner = ' + @Partner + ' ...'

	-- Select the intersecting species records into the temporary table
	SET @sqlcommand = 'INSERT INTO ' + @Schema + '.' + @TempTable + ' (' +
		'SPP_NAME ' +
		',LATIN_NAME ' +
		',RECORD_TAXON_CLASS ' +
		',TAXONOMIC_GROUP ' +
		',DATE_START ' +
		',DATE_END ' +
		',DATE_RANGE ' +
		',RECORDYEAR ' +
		',RECORDER ' +
		',DETERMINER ' +
		',VERIFICATION ' +
		',GRIDREF ' +
		',EASTINGS ' +
		',NORTHINGS ' +
      	',GRPRECISION ' +
		',QUALIFIER ' +
		',COMMENTS ' +
		',BREEDING_STATUS ' +
		',STATUS_PLANNING ' +
		',STATUS_OTHER ' +
		',STATUS_LISI ' +
		',CONFIDENTIAL ' +
		',SENSITIVE ' +
		',SORTORDER ' +
		',R6SURVEY ' +
		',RECORDERID_TOCC ' +
		',NEG_RECORD ' +
		',RECORDERID_TVK ' +
		',RECORDERID_TLIK ' +
		',RECORDERID_SYK ' +
		',RECORDERID_SPK ' +
		',RECDIC ' +
		',SP_GEOMETRY) ' +
		'SELECT ' +
		'Spp.[SPP_NAME] ' +
		',Spp.[LATIN_NAME] ' +
		',Spp.[RECORD_TAXON_CLASS] ' +
		',Spp.[TAXONOMIC_GROUP] ' +
		',Spp.[DATE_START] ' +
		',Spp.[DATE_END] ' +
		',Spp.[DATE_RANGE] ' +
		',Spp.[RECORDYEAR] ' +
		',Spp.[RECORDER] ' +
		',Spp.[DETERMINER] ' +
		',Spp.[VERIFICATION] ' +
		',Spp.[GRIDREF] ' +
		',Spp.[EASTINGS] ' +
		',Spp.[NORTHINGS] ' +
      	',Spp.[GRPRECISION] ' +
		',Spp.[QUALIFIER] ' +
		',Spp.[COMMENTS] ' +
		',Spp.[BREEDING_STATUS] ' +
		',Spp.[STATUS_PLANNING] ' +
		',Spp.[STATUS_OTHER] ' +
		',Spp.[STATUS_LISI] ' +
		',Spp.[CONFIDENTIAL] ' +
		',Spp.[SENSITIVE] ' +
		',Spp.[SORTORDER] ' +
		',Spp.[R6SURVEY] ' +
		',Spp.[RECORDERID_TOCC] ' +
		',Spp.[NEG_RECORD] ' +
		',Spp.[RECORDERID_TVK] ' +
		',Spp.[RECORDERID_TLIK] ' +
		',Spp.[RECORDERID_SYK] ' +
		',Spp.[RECORDERID_SPK] ' +
		',Spp.[RECDIC] ' +
		',Spp.[SP_GEOMETRY] ' +
		' FROM ' + @Schema + '.' + @SpeciesTable + ' As Spp, ' + @PartnerTable + ' As Poly' +
		' WHERE ' + @PartnerColumn + ' = ''' + @Partner + '''' +
--		' AND Spp.SP_GEOMETRY.Filter(Poly.SP_GEOMETRY) = 1'
		' AND Spp.SP_GEOMETRY.STIntersects(Poly.SP_GEOMETRY) = 1'
--		' AND Poly.SP_GEOMETRY IS NOT NULL'
	EXEC (@sqlcommand)

	DECLARE @RecCnt Int
	Set @RecCnt = @@ROWCOUNT

	If @debug = 1
		PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + Cast(@RecCnt As varchar) + ' records selected ...'

	-- If the MapInfo MapCatalog exists then update it
	if exists (select TABLE_NAME from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA = 'MAPINFO' and TABLE_NAME = 'MAPINFO_MAPCATALOG')
	BEGIN

		-- Drop the synonym for the table passed to the procedure if it 't already exists
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
			' FOR ' + @Schema + '.' + @TempTable
		EXEC (@sqlcommand)

		If @debug = 1
			PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Determining spatial extent ...'

		-- Calculate the geometric extent of the records (plus their precision)
		DECLARE
			@X1 int,
			@X2 int,
			@Y1 int,
			@Y2 int

		-- Retrieve the geometric extent values and store as variables
		SELECT  @X1 = MIN(EASTINGS),
				@Y1 = MIN(NORTHINGS),
				@X2 = MAX(EASTINGS) + MAX(GRPRECISION),
				@Y2 = MAX(NORTHINGS) + MAX(GRPRECISION)
		From Species_Temp

		-- Delete the MapInfo MapCatalog entry if it already exists
		if exists (select TABLENAME from [MAPINFO].[MAPINFO_MAPCATALOG] where TABLENAME = @TempTable)
		BEGIN
			If @debug = 1
				PRINT CONVERT(VARCHAR(32), CURRENT_TIMESTAMP, 109 ) + ' : ' + 'Deleting the MapInfo MapCatalog entry ...'
			SET @sqlcommand = 'DELETE FROM [MAPINFO].[MAPINFO_MAPCATALOG]' +
				' WHERE TABLENAME = ''' + @TempTable + ''''
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
			,@TempTable
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
