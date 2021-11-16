/***************************************/
-- # Exercise 6 - Spatio-Temporal Clustering
/***************************************/

/***************************************/
-- Let's create a view on our data table. This is optional, but it facilitates re-use of the code.
CREATE OR REPLACE VIEW "AIS_DEMO"."V_FILTERED_AIS_2017" AS (
	SELECT "ID", "MMSI", "TS", "SHAPE_32616" AS "LOC", 1 AS COU FROM "AIS_DEMO"."AIS_2017"
);

-- Function to calculate hex clusters for a given time slice.
-- The input is a spatial extent MIN/MAX X/Y and a temporal extent START/END timestamp.
-- It returns the result of a spatial clustering process for a single timeslice.
CREATE OR REPLACE FUNCTION "AIS_DEMO"."F_CALC_HEX_CLUSTER_FOR_TIMESLICE"(
    IN I_X INT, 
	IN I_X_MIN DOUBLE, IN I_X_MAX DOUBLE, 
	IN I_Y_MIN DOUBLE, IN I_Y_MAX DOUBLE, 
	IN I_START_TS TIMESTAMP, IN I_END_TS TIMESTAMP, IN I_ELEMENT_NUMBER INT
    )
    RETURNS TABLE ("CLUSTER_ID" INT, "COU" INT, "COU_DIST" INT, "ELEMENT_NUMBER" INT)
LANGUAGE SQLSCRIPT READS SQL DATA AS
BEGIN
	RES = SELECT ST_CLUSTERID() AS "CLUSTER_ID", COUNT(*) AS "COU", COUNT(DISTINCT "MMSI") AS "COU_DIST", :I_ELEMENT_NUMBER AS "ELEMENT_NUMBER"
		FROM "AIS_DEMO"."V_FILTERED_AIS_2017"
		WHERE "TS" >= :I_START_TS AND "TS" < :I_END_TS
		GROUP CLUSTER BY "LOC" USING HEXAGON 
		X BETWEEN :I_X_MIN AND :I_X_MAX CELLS :I_X 
		Y BETWEEN :I_Y_MIN AND :I_Y_MAX;
    RETURN :RES;
END;
--x, xmin, xmax, ymin, ymax, date, date
--SELECT * FROM "AIS_DEMO"."F_CALC_HEX_CLUSTER_FOR_TIMESLICE"(20, 368593.1366195679, 707119.9499664307, 4574894.745727539, 5098887.35975647, TO_TIMESTAMP('2017-05-26 10:05:00'), TO_TIMESTAMP('2017-05-27 10:10:00'), 1);

-- Quick sidestep: this is a basic query that generates a timeseries, subdividing the timespan according to the interval definition (8h)
SELECT T."GENERATED_PERIOD_START", T."GENERATED_PERIOD_END", T."ELEMENT_NUMBER", *
		FROM SERIES_GENERATE_TIMESTAMP('INTERVAL 8 HOUR', TO_TIMESTAMP('2017-06-01 00:00:00'), TO_TIMESTAMP('2017-06-30 23:59:00')) AS T;

	
-- This is an orchestration function - it calls the time-bounded functiona bove for each timeslice in the data.
-- Input is a basic grid definition: the number of cells in X direction
-- and a valid timeseries interval: see https://help.sap.com/viewer/c1d3f60099654ecfb3fe36ac93c121bb/latest/en-US/c8101037ad4344768db31e68e4d30eb4.html
CREATE OR REPLACE FUNCTION "AIS_DEMO"."F_CREATE_ST_CUBE"(
		IN I_X INT, -- number OF cells IN X direction
		IN I_INTERVAL VARCHAR(100) -- a valid timeseries expression, e.g. 'INTERVAL 1 DAY'
 	)
    RETURNS TABLE (
    	"CLUSTER_ID" INT, "ELEMENT_NUMBER" INT, "COU" INT, "COU_ALL" INT, "COU_DIST" INT, "COU_DIST_ALL" INT, 
    	"SHAPE" ST_GEOMETRY(32616), "START_TS" TIMESTAMP
   	)
LANGUAGE SQLSCRIPT READS SQL DATA AS
BEGIN
	DECLARE V_XMIN DOUBLE;
	DECLARE V_XMAX DOUBLE;
	DECLARE V_YMIN DOUBLE;
	DECLARE V_YMAX DOUBLE;
	DECLARE V_START_TS TIMESTAMP;
	DECLARE V_END_TS TIMESTAMP;
	DECLARE V_SRID INT = 32616;

	-- calculate the spatial extent (all data) and store the result in variables
	SELECT MIN("LOC".ST_X()), MAX("LOC".ST_X()), MIN("LOC".ST_Y()), MAX("LOC".ST_Y())
		INTO V_XMIN, V_XMAX, V_YMIN, V_YMAX
		FROM "AIS_DEMO"."V_FILTERED_AIS_2017";
	
	-- Calculate the hexagon cluster grid (all data)
	grid = SELECT ST_CLUSTERID() AS "CLUSTER_ID", ST_CLUSTERCELL() AS "SHAPE", COUNT(*) AS "COU_ALL", COUNT(DISTINCT "MMSI") AS "COU_DIST_ALL"
		FROM "AIS_DEMO"."V_FILTERED_AIS_2017"
		GROUP CLUSTER BY "LOC" USING HEXAGON X BETWEEN :V_XMIN AND :V_XMAX CELLS :I_X Y BETWEEN :V_YMIN AND :V_YMAX;
	
	-- Calculate the timeslice intervals according to provided interval definition, e.g. 1 DAY
	-- First get the minimun and maximum timestamp, i.e. the timespan of the data
	SELECT MIN("TS"), MAX("TS")	INTO V_START_TS, V_END_TS FROM "AIS_DEMO"."V_FILTERED_AIS_2017";
	-- then generate a timeseries
	time_slices = SELECT T."GENERATED_PERIOD_START", T."GENERATED_PERIOD_END", TO_INT(T."ELEMENT_NUMBER") AS "ELEMENT_NUMBER"
		FROM SERIES_GENERATE_TIMESTAMP(:I_INTERVAL, :V_START_TS, :V_END_TS) AS T;
	
	-- Call the clustering function for each individual time slice
	-- The MAP_MERGE operator calls the functions in parallel and merges the results into a single table: grid_temporal
	grid_temporal = MAP_MERGE(:time_slices, "AIS_DEMO"."F_CALC_HEX_CLUSTER_FOR_TIMESLICE"(:I_X, :V_XMIN, :V_XMAX, :V_YMIN, :V_YMAX,
		:time_slices."GENERATED_PERIOD_START", :time_slices."GENERATED_PERIOD_END", :time_slices."ELEMENT_NUMBER"));

	-- A little bit of NULL handling 
    RETURN SELECT grid."CLUSTER_ID", time_slices."ELEMENT_NUMBER", COALESCE(grid_temporal."COU", 0) AS "COU", grid."COU_ALL", 
    			COALESCE(grid_temporal."COU_DIST", 0) AS "COU_DIST", grid."COU_DIST_ALL", grid."SHAPE", time_slices."GENERATED_PERIOD_START" AS "START_TS"
    	FROM :grid AS grid
    	FULL OUTER JOIN :time_slices AS time_slices ON 1=1 
    	LEFT JOIN :grid_temporal AS grid_temporal ON grid_temporal."CLUSTER_ID" = grid."CLUSTER_ID" AND grid_temporal."ELEMENT_NUMBER" = time_slices."ELEMENT_NUMBER";
END;

-- Call the function - hte first parameter is the number of grid cells in X direction, the second is a time interval definition 
--SELECT * FROM "AIS_DEMO"."F_CREATE_ST_CUBE"(30, 'INTERVAL 1 DAY') ORDER BY "CLUSTER_ID", "ELEMENT_NUMBER";



-- Store the data in a table so, we can run timeseries forecasting
CREATE COLUMN TABLE "AIS_DEMO"."ST_CUBE" AS ( 
	SELECT *, TO_DECIMAL(("COU"/"COU_ALL")*100, 5,2) AS "PERC", TO_DECIMAL(("COU_DIST"/"COU_DIST_ALL")*100, 5,2) AS "PERC_DIST"
	FROM "AIS_DEMO"."F_CREATE_ST_CUBE"(50, 'INTERVAL 4 HOUR')
);
SELECT * FROM "AIS_DEMO"."ST_CUBE" WHERE "CLUSTER_ID" = 562 ORDER BY "ELEMENT_NUMBER";


