# Exercise 1 - Prepare the Data

In this exercise, we will load the data from an Amazon S3 bucket into a HANA table, do some data transformations and clean-up. Alternatively, you can also just import the [database export file export.gz](../data_and_script). This export file contains all the data you need for the subsequent exercises.

## Import the Raw Data<a name="subex1"></a>

```SQL
-- Create a database schema
CREATE SCHEMA "AIS_DEMO";
-- Create a database table for importing the data
CREATE COLUMN TABLE "AIS_DEMO"."IMPORT" (
	"MMSI" INT, "TS" TIMESTAMP, "LAT" DOUBLE, "LON" DOUBLE, "SOG" DOUBLE, "COG" DOUBLE, "HEADING" DOUBLE, "VESSELNAME" NVARCHAR(500),
	"IMO" NVARCHAR(500), "CALLSIGN" NVARCHAR(500), "VESSELTYPE" INT, "STATUS" NVARCHAR(500), "LENGTH" DOUBLE, "WIDTH" DOUBLE, "DRAFT" DOUBLE,
	"CARGO" INT
);
-- Data import from S3, example syntax
IMPORT FROM CSV FILE 's3-<region>://<access_key>:<secret_key>@<bucket_name>/AIS_2017_05_Zone16.csv'
	INTO "AIS_DEMO"."IMPORT"
	WITH FIELD DELIMITED BY ',' OPTIONALLY ENCLOSED BY '"' threads 20;
-- We want to work with data from the Lake Michigan area.
-- So, let's copy the relevant data into a single table
CREATE COLUMN TABLE "AIS_DEMO"."AIS_2017" AS (
	SELECT * FROM "AIS_DEMO"."IMPORT"
	WHERE "LAT" BETWEEN 41.25 AND 46.09 AND "LON" BETWEEN -88.57 AND -84.34
);
-- Some clients like ArcGIS Pro require a primary key, so let's generate one.
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("ID" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY);

```

## Generate Geometries<a name="subex2"></a>

You may have noticed that the geolocations are stored in two columns with datatype DOUBLE: "LAT" and "LON". We will transform the geolocation to the ST_GEOMETRY datatype, but first we need to created the right Spatial Reference Systems (SRS) in HANA.

```SQL
-- Add the required spatial reference systems.
CREATE PREDEFINED SPATIAL REFERENCE SYSTEM IDENTIFIED BY 4269;
CREATE PREDEFINED SPATIAL REFERENCE SYSTEM IDENTIFIED BY 32616;
-- Add two columns to the data table...
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("SHAPE_4269" ST_GEOMETRY(4269));
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("SHAPE_32616" ST_GEOMETRY(32616));
-- ... and generate geometries from the LON/LAT values.
UPDATE "AIS_DEMO"."AIS_2017" SET "SHAPE_4269" = ST_GeomFromText('POINT('||LON||' '||LAT||')', 4269);
UPDATE "AIS_DEMO"."AIS_2017" SET "SHAPE_32616" = "SHAPE_4269".ST_TRANSFORM(32616);
```
## Remove Duplicates<a name="subex3"></a>

There are duplicates in the raw data. For some timestamps and  vessels - identified by the MMSI (Maritime Mobile Service Identity) - there are two identical records in the data. Let's get rid of the duplicates.

```SQL
-- Identify duplicate records
SELECT "MMSI", "TS", COUNT(*) AS C FROM "AIS_DEMO"."AIS_2017" GROUP BY "MMSI", "TS" HAVING COUNT(*) > 1 ORDER BY C DESC;
-- We'll add a DELETE falg to the records
ALTER TABLE "AIS_DEMO"."AIS_2017" ADD ("DELETE" BOOLEAN);
-- The set the flag to TRUE
MERGE INTO "AIS_DEMO"."AIS_2017"
USING
	(SELECT "MMSI", "TS" FROM "AIS_DEMO"."AIS_2017" GROUP BY "MMSI", "TS" HAVING COUNT(*) > 1) AS DUP
	ON "AIS_DEMO"."AIS_2017"."MMSI" = DUP."MMSI" AND "AIS_DEMO"."AIS_2017"."TS" = DUP."TS"
	WHEN MATCHED THEN UPDATE SET "AIS_DEMO"."AIS_2017"."DELETE" = TRUE;
-- And finally delete the flagged records
DELETE FROM "AIS_DEMO"."AIS_2017" WHERE "DELETE" = TRUE;
```

## Summary

We loaded two large flat files from an S3 bucket, generated geometry columns in the table, and did some clean up. We are now ready to work with the data.

Continue to - [Exercise 2 - Identify Vessels within National Park Boundaries](../ex2/README.md)
