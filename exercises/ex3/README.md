# Exercise 3 - Understand Vessel Motion

In the last exercise we have seen how to construct a path from point observations using ST_MakeLine(). We will now extend this query pattern to also calculate motion statistics like **speed** and **acceleration**. Next we will take a look at individual trajectories of cargo and passenger ships before we identify **dwell locations**, i.e. when ships stop for a period of time before starting the next trip segment.

## Derive Speed, Acceleration, Total Distance, and Total Time<a name="subex1"></a>

We will calculate the basic motion statistics in three steps, using three stacked SQL views for better understanding. In sequence, we will calculate
<ol><li>the time interval and distance between each pair of consecutive vessel observations: "delta s" and "delta t"</li>
<li>from "delta s" and "delta t" we will derive the vessel's speed and sum up time and distance</li>
<li>looking at the change in speed, we can calculate acceleration</li></ol>

All the views below make use of window functions where the data is partitioned by "MMSI" (used as the vessel identifier) and ordered by timestamp. In specific, we will use RANK() which returns an order number, and LAG() which provides access to the next record in the ordered partition. See als [docu].
```SQL
-- Step 1: delta s, delta t, ranks, partial lines
CREATE OR REPLACE VIEW "AIS_DEMO"."V_MOTION_STATS_1" AS (
	SELECT "MMSI", "SHAPE_32616" AS "P", "TS",
		CAST("SHAPE_32616".ST_DISTANCE(LAG("SHAPE_32616", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), 'meter') AS DECIMAL(10,2)) AS "DELTA_S",
		SECONDS_BETWEEN(LAG("TS", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), "TS") AS "DELTA_T",
		ST_MAKELINE(LAG("SHAPE_32616", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), "SHAPE_32616") AS "LINE_32616",
		RANK() OVER(PARTITION BY "MMSI" ORDER BY "TS") AS "FWD_RANK",
		RANK() OVER(PARTITION BY "MMSI" ORDER BY "TS" DESC) AS "BWD_RANK"
	FROM "AIS_DEMO"."AIS_2017"
	WHERE "MMSI" = 366780000 AND "TS" BETWEEN '2017-06-24 10:00:00' AND '2017-06-25 10:00:00'
);
SELECT * FROM "AIS_DEMO"."V_MOTION_STATS_1" ORDER BY "TS" ASC;
```
The view above calculates forward and backward rank, the time interval and distance ("DELTA_T" and "DELTA_S") between consecutive observations, and generates a linestring which connects the points. For simplicity reasons, we are analyzing a single ship's movement in a 24h interval. We see that the time interval between two AIS signals is about 70 seconds and the distance is greater that 200 meters at first, but then drops below 200 meters around 10:12.
<br>![](images/step1.png)


The next piece of logic calculates the speed in m/s, dividing "DELTA_S" by "DELTA_T", and sums up "DELTA_S" and "DELTA_T" so we understand how long and how far a ship has travelled up to that point.
```SQL
-- Step 2: sum up delta s and delta t, calculate speed
CREATE OR REPLACE VIEW "AIS_DEMO"."V_MOTION_STATS_2" AS (
	SELECT SUM("DELTA_S") OVER(PARTITION BY "MMSI" ORDER BY "TS" ASC) AS "TOTAL_DISTANCE",
			SUM("DELTA_T") OVER(PARTITION BY "MMSI" ORDER BY "TS" ASC) AS "TOTAL_TIMESPAN",
			"DELTA_S"/"DELTA_T" AS "SPEED_M/S", *
		FROM "AIS_DEMO"."V_MOTION_STATS_1"
);
SELECT * FROM "AIS_DEMO"."V_MOTION_STATS_2" ORDER BY "TS" ASC;
```
The second view above adds "TOTAL_DISTANCE", "TOTAL_TIMESPAN", and "SPEED_M/S". Looking at line 11 we see that the ship has travelled 2714 meter in 690 seconds, running with a current speed of 3.345 m/sec.
<br>![](images/step2.png)

In the last step, we calculate the acceleration, dividing the change in speed by the time interval.
```SQL
-- Step 3: calculate acceleration
CREATE OR REPLACE VIEW "AIS_DEMO"."V_MOTION_STATS_3" AS (
	SELECT  ("SPEED_M/S"-LAG("SPEED_M/S", 1) OVER(ORDER BY "TS" ASC))/("DELTA_T") AS "ACCELERATION", *
		FROM "AIS_DEMO"."V_MOTION_STATS_2"
);
SELECT * FROM "AIS_DEMO"."V_MOTION_STATS_3" ORDER BY "TS" ASC;
```
So, looking at the first column in the table below we see the ship is decelerating (negative values) when approaching the harbor, reducing the speed from 3.4 m/sec to 1.6 m/sec.
<br>![](images/step3.png)

Next, we will wrap the logic of the three SQL views above into a single user-defined function. This will allow very flexible filtering - we can simply pass a valid WHERE condition in the parameter i_filter. This filter is applied on our AIS_2017 table using the APPLY_FILTER() function (... strange name for this function, do you agree?). The filtered data "DAT" is the data on which we run our motion statistics logic. The resulting dataset "MS" is then returned by the function.
```SQL
-- Now, let's wrap the 3-step logic of the SQL views above into a single function
CREATE OR REPLACE FUNCTION "AIS_DEMO"."F_MOTION_STATS" (IN i_filter NVARCHAR(5000))
RETURNS TABLE ("MMSI" INT, "TS" TIMESTAMP, "TOTAL_DISTANCE" DECIMAL(10,2), "TOTAL_TIMESPAN" DECIMAL(10,2), "SPEED_M/S" DECIMAL(10,2), "ACCELERATION" DECIMAL(10,3),
	"LINE_32616" ST_GEOMETRY(32616),
	"SOG" REAL, "COG" REAL, "VESSELNAME" NVARCHAR(500), "VESSELTYPE" INT, "CARGO" INTEGER, "SHAPE_32616" ST_GEOMETRY(32616), "ID" BIGINT,
	"FWD_RANK" INT, "BWD_RANK" INT, "DELTA_T" INT, "DELTA_S" DECIMAL(10,2),
	"DATE" DATE, "WEEKDAY" INT, "HOUR" INT)
AS BEGIN
	DAT = APPLY_FILTER("AIS_DEMO"."AIS_2017", :i_filter);
	MS = SELECT *, CAST(("SPEED_M/S"-LAG("SPEED_M/S", 1) OVER(ORDER BY "TS" ASC))/("DELTA_T") AS DECIMAL(10,3)) AS "ACCELERATION"
		FROM (
			SELECT	CAST(SUM("DELTA_S") OVER(PARTITION BY "MMSI" ORDER BY "TS" ASC) AS DECIMAL(10,2)) AS "TOTAL_DISTANCE",
					CAST(SUM("DELTA_T") OVER(PARTITION BY "MMSI" ORDER BY "TS" ASC) AS DECIMAL(10,2)) AS "TOTAL_TIMESPAN",
					CAST("DELTA_S"/("DELTA_T") AS DECIMAL(10,2)) AS "SPEED_M/S",
					TO_DATE("TS") AS "DATE", WEEKDAY("TS") AS "WEEKDAY", HOUR("TS") AS "HOUR", *
				FROM (
					SELECT "MMSI", "VESSELNAME", "VESSELTYPE", "CARGO", "ID", "SHAPE_32616", "TS", "SOG", "COG",
						ST_MAKELINE(LAG("SHAPE_32616", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), "SHAPE_32616") AS "LINE_32616",
						RANK() OVER(PARTITION BY "MMSI" ORDER BY "TS") AS "FWD_RANK",
						RANK() OVER(PARTITION BY "MMSI" ORDER BY "TS" DESC) AS "BWD_RANK",
						CAST("SHAPE_32616".ST_DISTANCE(LAG("SHAPE_32616", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), 'meter') AS DECIMAL(10,2)) AS "DELTA_S",
						SECONDS_BETWEEN(LAG("TS", 1) OVER(PARTITION BY "MMSI" ORDER BY "TS"), "TS") AS "DELTA_T"
					FROM :DAT
				)
		);
	RETURN SELECT "MMSI", "TS", "TOTAL_DISTANCE", "TOTAL_TIMESPAN", "SPEED_M/S", "ACCELERATION", "LINE_32616", "SOG", "COG", "VESSELNAME", "VESSELTYPE", "CARGO",
		"SHAPE_32616", "ID", "FWD_RANK", "BWD_RANK", "DELTA_T", "DELTA_S", "DATE", "WEEKDAY", "HOUR"
		FROM :MS
		ORDER BY "MMSI", "FWD_RANK";
END;

-- Let's inspect some motion statistics
SELECT * FROM "AIS_DEMO"."F_MOTION_STATS"(' "MMSI" = 366780000 AND "TS" BETWEEN ''2017-06-24 10:00:00'' AND ''2017-06-25 10:00:00'' ');
SELECT * FROM "AIS_DEMO"."F_MOTION_STATS"(' "VESSELTYPE" = 1004 AND "TS" BETWEEN ''2017-06-01 00:00:00'' AND ''2017-06-07 23:00:00'' ');
```
Here is a how the motion statistics could look like in QGIS. The first screenshot shows the vessel's speed (red=fast blue=slow) observed in a 3 hour interval. The second screenshot visualizes "traces" of vessels. The more transparent the line is, the more the observations happened in the past.
<br>![](images/speed.png)
<br><br>![](images/trace.png)

We can use the user-defined function "F_MOTION_STATS" as sub-query or derive additional statistics from the result. The below query for example takes the fine granular motion statistics and calculates hourly average and maximum of speed for a 7 day interval.
```SQL
SELECT HOUR("TS"), COUNT(*), COUNT(DISTINCT "MMSI"), AVG("SPEED_M/S"), MAX("SPEED_M/S")
	FROM "AIS_DEMO"."F_MOTION_STATS"(' "TS" BETWEEN ''2017-06-01 00:00:00'' AND ''2017-06-07 24:00:00'' ') WHERE "SPEED_M/S" > 0.5
	GROUP BY HOUR("TS")
	ORDER BY HOUR("TS");
```
We can see htat the average speed is highest in the early PMs, but the maximum speed was observed between 10PM and midnight.
<br>![](images/hourly_stats.png)



## Summary

You've now ...

Continue to - [Exercise 3 - Excercise 3 ](../ex3/README.md)
