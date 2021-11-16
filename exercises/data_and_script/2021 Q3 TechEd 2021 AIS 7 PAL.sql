/***************************************/
-- # Exercise 7 - Predict Traffic
/***************************************/

/****************************/
-- We will create a space-time cube leveraging the spatio-temporal clustering function from ex 6
-- The table will be the basis for running timeseries forecasting of AIS observations, i.e. traffic 
/****************************/
DROP TABLE "AIS_DEMO"."ST_CUBE";
CREATE COLUMN TABLE "AIS_DEMO"."ST_CUBE" AS ( 
	SELECT *, TO_DECIMAL(("COU"/"COU_ALL")*100, 5,2) AS "PERC", TO_DECIMAL(("COU_DIST"/"COU_DIST_ALL")*100, 5,2) AS "PERC_DIST"
	FROM "AIS_DEMO"."F_CREATE_ST_CUBE"(50, 'INTERVAL 4 HOUR')
);
-- Our ST_CUBE table contains 570k records, representing 1568 cluster cells and 365 elements, i.e. 4h interval timeslices
-- Let's take a look at the data for cluster 562, which is near the Chicago port
SELECT COUNT(*) FROM "AIS_DEMO"."ST_CUBE";
SELECT * FROM "AIS_DEMO"."ST_CUBE" WHERE "CLUSTER_ID" = 562 ORDER BY "ELEMENT_NUMBER";

-- Check consistency of Cube
-- timeslices per cell=cluster_id, should be 365
SELECT "CLUSTER_ID", "SHAPE", SUM("COU"), SUM("COU_DIST"), COUNT(*) AS "NUMBER_OF_TIMESLICES" 
	FROM "AIS_DEMO"."ST_CUBE"
	GROUP BY "CLUSTER_ID", "SHAPE" ORDER BY SUM("COU") DESC;
-- cells per time slice, should be 1568
SELECT "ELEMENT_NUMBER", "START_TS", SUM("COU"), SUM("COU_DIST"), COUNT(*) AS "NUMBER_OF_CELLS" 
	FROM "AIS_DEMO"."ST_CUBE"
	GROUP BY "ELEMENT_NUMBER", "START_TS" ORDER BY SUM(COU) DESC;


/*****************************/
-- For the sake of simplicity, we create a view on top of or ST_CUBE to expose the data to Predictive Analysis Library (PAL)
-- We want to forecast observations for each cluster cell.
-- Each cluster cell has 365 timeslices, representing the observations in a 4h interval
-- We use PAL (Massive) Unified Exponential Smoothing for timeseries forecasting, in specific (Massive) Auto Exponential Smoothing
CREATE OR REPLACE VIEW "AIS_DEMO"."UES_DATA" AS (
	SELECT "CLUSTER_ID", "ELEMENT_NUMBER", "COU_DIST" AS "OBSERVED_VALUE", "SHAPE", "START_TS" FROM "AIS_DEMO"."ST_CUBE"
);
-- We need a table to store the results of our forecast: UES_FORECAST
CREATE COLUMN TABLE "AIS_DEMO"."UES_FORECAST" (
	"CLUSTER_ID" INT, "ELEMENT_NUMBER" INT, "FORCASTED_VALUE" DOUBLE, "PI1_LOWER" DOUBLE, "PI1_UPPER" DOUBLE, "PI2_LOWER" DOUBLE, "PI2_UPPER" DOUBLE
);
TRUNCATE TABLE "AIS_DEMO"."UES_FORECAST";

-- The following code block generates the parameters for our PAL UES algorithm, executes the algorithms, and stores the results
-- We run 1568 forecasts in parallel
DO BEGIN
	-- declare parameters
	DECLARE lt_param0 TABLE("PARAM_NAME" VARCHAR (100), "INT_VALUE" INTEGER, "DOUBLE_VALUE" DOUBLE, "STRING_VALUE" VARCHAR (100));
	:lt_param0.INSERT(( 'FUNCTION', NULL, NULL,'MAESM'), 1);
    :lt_param0.INSERT(( 'THREAD_RATIO', NULL, 5.0, NULL), 2);
    :lt_param0.INSERT(( 'FORECAST_NUM', 12, NULL, NULL), 3); 
    :lt_param0.INSERT(( 'MODELSELECTION', 1, NULL, NULL), 4); 
    :lt_param0.INSERT(( 'MAX_ITERATION', 500, NULL, NULL), 5);
    :lt_param0.INSERT(( 'MEASURE_NAME', NULL, NULL,'MAPE'), 6);
	-- set params and data
	lt_param = SELECT DAT."GROUP_ID", P.* FROM :lt_param0 AS P CROSS JOIN (SELECT DISTINCT "CLUSTER_ID" AS "GROUP_ID" FROM "AIS_DEMO"."UES_DATA") AS DAT;
	lt_data = SELECT "CLUSTER_ID", "ELEMENT_NUMBER", "OBSERVED_VALUE" FROM "AIS_DEMO"."UES_DATA";
	-- call UES
	CALL _SYS_AFL.PAL_UNIFIED_EXPONENTIALSMOOTHING(:lt_data, :lt_param, t_forecast, t_stats, f_errmsge, pl1, pl2);
	-- store results
	INSERT INTO "AIS_DEMO"."UES_FORECAST" ("CLUSTER_ID", "ELEMENT_NUMBER", "FORCASTED_VALUE", "PI1_LOWER", "PI1_UPPER", "PI2_LOWER", "PI2_UPPER") 
		SELECT "GROUP_ID" AS "CLUSTER_ID", "TIMESTAMP" AS "ELEMENT_NUMBER", "VALUE", "PI1_LOWER", "PI1_UPPER", "PI2_LOWER", "PI2_UPPER"
		FROM :t_forecast;
	-- get the stats
	SELECT "GROUP_ID", "STAT_NAME", "STAT_VALUE" FROM :t_stats WHERE "STAT_NAME" IN ('FORECAST_MODEL_NAME', 'MSE');
END;

SELECT * FROM "AIS_DEMO"."UES_FORECAST" WHERE "CLUSTER_ID" = 562 ORDER BY "ELEMENT_NUMBER" DESC;


-- Joining the historic data and forecast to view them side-by-side
CREATE OR REPLACE VIEW "AIS_DEMO"."V_UES_FORECAST" AS (
	SELECT FORC."CLUSTER_ID", FORC."ELEMENT_NUMBER", FORC."FORCASTED_VALUE", FORC."PI1_LOWER", FORC."PI1_UPPER", FORC."PI2_LOWER", FORC."PI2_UPPER", 
		DAT."OBSERVED_VALUE", DAT."SHAPE", 
		TO_SECONDDATE (TSERIES."GENERATED_PERIOD_START") AS "START_TS"
	FROM "AIS_DEMO"."UES_FORECAST" AS FORC
	LEFT JOIN "AIS_DEMO"."UES_DATA" AS DAT ON FORC."ELEMENT_NUMBER" = DAT."ELEMENT_NUMBER" AND FORC."CLUSTER_ID" = DAT."CLUSTER_ID"
	LEFT JOIN (SELECT T."GENERATED_PERIOD_START", T."GENERATED_PERIOD_END", T."ELEMENT_NUMBER"
		FROM SERIES_GENERATE_TIMESTAMP('INTERVAL 4 HOUR', '2017-05-01 00:00:00', '2017-07-07 24:00:00') AS T) AS TSERIES
		ON FORC."ELEMENT_NUMBER" = TSERIES."ELEMENT_NUMBER"
);
--SELECT * FROM "AIS_DEMO"."V_UES_FORECAST" ORDER BY CLUSTER_ID;
SELECT * FROM "AIS_DEMO"."V_UES_FORECAST" WHERE CLUSTER_ID IN (562) ORDER BY ELEMENT_NUMBER DESC;

-- Depending on the data in each timeseries, not all forecasts might be complete.
-- How many many time intervals could be forecasted?
SELECT "CLUSTER_ID", COUNT(*) AS "NUMBER_OF_ELEMENTS", MAX("ELEMENT_NUMBER") AS "MAX_ELEMENT", MAX("START_TS") AS "MAX_TS", 
	AVG("FORCASTED_VALUE") AS V
	FROM "AIS_DEMO"."V_UES_FORECAST" GROUP BY "CLUSTER_ID" ORDER BY V DESC;

