/***************************************/
-- # Exercise 2 - Identify Vessels within National Park Boundaries
/***************************************/

-- We have a table which contains the boundaries of a national park
SELECT * FROM "AIS_DEMO"."PARK_BOUNDARIES";

-- How many AIS observations and distinct vessels are located within the park boundaries?
SELECT COUNT(*), COUNT(DISTINCT "MMSI") 
	FROM "AIS_DEMO"."AIS_2017" AS D, "AIS_DEMO"."PARK_BOUNDARIES" AS B
	WHERE D."SHAPE_32616".ST_Within(B."SHAPE_32616") = 1; 

-- Handled by a SQLScript code block it is faster.
DO() BEGIN
	DECLARE BOUNDARY ST_Geometry;
	SELECT "SHAPE_32616" INTO BOUNDARY FROM "AIS_DEMO"."PARK_BOUNDARIES";
	SELECT COUNT(*), COUNT(DISTINCT "MMSI") 
	FROM "AIS_DEMO"."AIS_2017" AS D
	WHERE D."SHAPE_32616".ST_Within(:BOUNDARY) = 1;
END;

-- Which vessels and when? Get the single point observations and construct a simple route.
SELECT "MMSI", "VESSELNAME", MIN("TS"), MAX("TS"), 
		ST_COLLECTAGGR("SHAPE_32616") AS "OBSERVATIONS", 
		ST_COLLECTAGGR("LINE_32616") AS "ROUTE"
	FROM (
		SELECT D."MMSI", D."TS", D."VESSELNAME", D."SHAPE_32616", 
			ST_MAKELINE(LAG(D."SHAPE_32616", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), D."SHAPE_32616") AS "LINE_32616" 
			FROM "AIS_DEMO"."AIS_2017" AS D, "AIS_DEMO"."PARK_BOUNDARIES" AS B
		WHERE D."SHAPE_32616".ST_Within(B."SHAPE_32616") = 1
	)
	GROUP BY "MMSI", "VESSELNAME";

-- Create a view to display these observation in QGIS.
CREATE OR REPLACE VIEW "AIS_DEMO"."V_VESSELS_WITHIN_PARK_BOUNDARIES" AS (
	SELECT "MMSI", "VESSELNAME", MIN("TS"), MAX("TS"), ST_COLLECTAGGR("SHAPE_32616") AS "OBSERVATIONS", ST_COLLECTAGGR("LINE_32616") AS "ROUTE" FROM (
		SELECT D."MMSI", D."TS", D."VESSELNAME", D."SHAPE_32616", ST_MAKELINE(LAG(D."SHAPE_32616", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), D."SHAPE_32616") AS "LINE_32616" 
		FROM "AIS_DEMO"."AIS_2017" AS D, "AIS_DEMO"."PARK_BOUNDARIES" AS B
		WHERE D."SHAPE_32616".ST_Within(B."SHAPE_32616") = 1
	) GROUP BY "MMSI", "VESSELNAME"
); 