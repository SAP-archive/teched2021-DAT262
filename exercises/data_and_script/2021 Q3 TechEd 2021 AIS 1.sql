/***************************************/
-- # Exercise 1 - Prepare the Data
/***************************************/

-- Import files
--	DAT262_AIS_DEMO_AIS_2017_05_RAW_BINARY.tar.gz
--	DAT262_AIS_DEMO_AIS_2017_06_RAW_BINARY.tar.gz
--	DAT262_AIS_DEMO_BOUNDARIES_TEXT.tar.gz

-- ## Merge Tables
-- After the import, there are two tables AIS_DEMO.AIS_2017 and AIS_DEMO.AIS_2017_06
SELECT COUNT(*) FROM "AIS_DEMO"."AIS_2017"; --3.7 mio
SELECT COUNT(*) FROM "AIS_DEMO"."AIS_2017_06"; --4.6 mio

-- We copy the data from the second table into the first, so it is all in one place.
INSERT INTO "AIS_DEMO"."AIS_2017" SELECT * FROM "AIS_DEMO"."AIS_2017_06"; 
SELECT COUNT(*) FROM "AIS_DEMO"."AIS_2017"; --8.4 mio
-- After the copy, we can drop the second table
DROP TABLE "AIS_DEMO"."AIS_2017_06";
-- Some clients like ArcGIS Pro require a primary key, so let's generate one.
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("ID" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY);

-- Inspect the data
SELECT * FROM "AIS_DEMO"."AIS_2017" ORDER BY "MMSI", "TS" ASC;


-- ## Generate Geometries
-- Transform the geo-locations encoded by LAT/LON to a "real" geometry.
-- We will use two spatial reference systems, let's create these.
CREATE PREDEFINED SPATIAL REFERENCE SYSTEM IDENTIFIED BY 4269;
CREATE PREDEFINED SPATIAL REFERENCE SYSTEM IDENTIFIED BY 32616;
-- Add two columns to the data table...
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("SHAPE_4269" ST_GEOMETRY(4269));
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("SHAPE_32616" ST_GEOMETRY(32616));
-- ... and generate geometries from the LON/LAT values. 
UPDATE "AIS_DEMO"."AIS_2017" SET "SHAPE_4269" = ST_GeomFromText('POINT('||LON||' '||LAT||')', 4269);
UPDATE "AIS_DEMO"."AIS_2017" SET "SHAPE_32616" = "SHAPE_4269".ST_TRANSFORM(32616);


-- ## Remove Duplicates
-- Identify duplicate records
SELECT "MMSI", "TS", COUNT(*) AS C FROM "AIS_DEMO"."AIS_2017" GROUP BY "MMSI", "TS" HAVING COUNT(*) > 1 ORDER BY C DESC;

DELETE FROM "AIS_DEMO"."AIS_2017" WHERE (MMSI, TS) IN
(
	SELECT "MMSI", "TS" FROM "AIS_DEMO"."AIS_2017" GROUP BY "MMSI", "TS" HAVING COUNT(*) > 1
);

-- inspect the data
SELECT * FROM "AIS_DEMO"."AIS_2017" ORDER BY "MMSI", "TS" ASC;
SELECT "MMSI", "TS", "LAT", "LON", "SHAPE_32616" FROM "AIS_DEMO"."AIS_2017" ORDER BY "MMSI", "TS" ASC;
SELECT COUNT(*), MIN(TS), MAX(TS) FROM "AIS_DEMO"."AIS_2017";
SELECT COUNT(DISTINCT "MMSI") AS "Number of vessels" FROM "AIS_DEMO"."AIS_2017";
-- Number of observations per vessel
SELECT "MMSI", COUNT(*) AS C FROM "AIS_DEMO"."AIS_2017" GROUP BY "MMSI" ORDER BY C DESC;
-- Number of observations per vessel per day
SELECT "MMSI", TO_DATE("TS"), COUNT(*) AS C FROM "AIS_DEMO"."AIS_2017" GROUP BY "MMSI", TO_DATE("TS") ORDER BY C DESC;


