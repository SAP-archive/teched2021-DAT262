/***************************************/
-- # Exercise 9 - Document Store and Graph
/***************************************/
-- GDELT Global Entity Graph (GEG)
-- https://blog.gdeltproject.org/announcing-the-global-entity-graph-geg-and-a-new-11-billion-entity-dataset/
-- JSON data is imported via hana-ml, or by uploading the data file DAT262_AIS_DEMO_GEG.tar.gz

-- Inspect the data that is store in a JSON Document Store collection.
-- A collection looks like a single-column table and stores JSON documents.
SELECT * FROM "AIS_DEMO"."GDELT_GEG" WHERE "lang" = 'en' LIMIT 20;
SELECT COUNT(*) FROM "AIS_DEMO"."GDELT_GEG";

-- UNNEST the entities array of each document
SELECT "url", "lang", E."mid", E."name", E."type", E."avgSalience"
	FROM "AIS_DEMO"."GDELT_GEG"
	UNNEST "entities" AS E
	WHERE E."type" IN ('PERSON', 'ORGANIZATION', 'LOCATION', 'EVENT') AND "lang" = 'en';

-- Let's create a view that provides access tp the entities in hte documents
CREATE OR REPLACE VIEW "AIS_DEMO"."V_GEG_ENTITIES" AS (
SELECT TO_NVARCHAR("url") AS "url", TO_NVARCHAR("lang") AS "lang", TO_NVARCHAR(E."mid") AS "mid", TO_NVARCHAR(E."name") AS "name", TO_NVARCHAR(E."type") AS "type", TO_DOUBLE(E."avgSalience") AS "avgSalience"
		FROM "AIS_DEMO"."GDELT_GEG"
		UNNEST "entities" AS E
		WHERE E."type" IN ('PERSON', 'ORGANIZATION', 'LOCATION', 'EVENT')
);
SELECT * FROM "AIS_DEMO"."V_GEG_ENTITIES";
-- The GEG includes information from different languages. Let's count the number of entities by langauge
SELECT "lang", COUNT(*) AS C FROM "AIS_DEMO"."V_GEG_ENTITIES" GROUP BY "lang" ORDER BY C DESC;

-- Let's create graph edges, i.e. relations between entities based on their co-occurrence.
-- We simply join the collection to itself, using the "url" as join key.
CREATE OR REPLACE VIEW "AIS_DEMO"."V_GEG_EDGES" AS (
	SELECT "ID1", "N1", "T1", "ID2", "N2", "T2", AVG("SALIENCE") AS "SALIENCE", COUNT(*) AS COU FROM (
		SELECT COALESCE(T1."mid", T1."name"||'-'||T1."lang"||'-'||T1."type") AS "ID1", T1."name" AS "N1", T1."type" AS "T1", 
			COALESCE(T2."mid", T2."name"||'-'||T2."lang"||'-'||T2."type") AS "ID2", T2."name" AS "N2", T2."type" AS "T2", (T1."avgSalience"*T2."avgSalience") AS SALIENCE
		FROM "AIS_DEMO"."V_GEG_ENTITIES" AS T1 
		LEFT JOIN "AIS_DEMO"."V_GEG_ENTITIES" AS T2 ON T1."url" = T2."url"
		WHERE T1."name" != T2."name"
	)
	GROUP BY "ID1", "N1", "T1", "ID2", "N2", "T2"
);
-- We will select only the most prominent entity pairs, e.g. where the average salience is above a threshold.
SELECT * FROM "AIS_DEMO"."V_GEG_EDGES" WHERE SALIENCE > 0.004 ORDER BY COU DESC;

-- Store the data in a table
CREATE COLUMN TABLE "AIS_DEMO"."GDELT_GEG_EDGES" (
	"ID" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	"SOURCE" nvarchar(1000) NOT NULL,
	"SOURCE_NAME" nvarchar(1000),
	"SOURCE_TYPE" nvarchar(1000) NOT NULL,
	"TARGET" nvarchar(1000) NOT NULL,
	"TARGET_NAME" nvarchar(1000),
	"TARGET_TYPE" nvarchar(1000) NOT NULL,
	"SALIENCE" DOUBLE,
	"COU" BIGINT
);

INSERT INTO "AIS_DEMO"."GDELT_GEG_EDGES"("SOURCE", "SOURCE_NAME", "SOURCE_TYPE", "TARGET", "TARGET_NAME", "TARGET_TYPE", "SALIENCE", "COU")
	SELECT * FROM "AIS_DEMO"."V_GEG_EDGES" WHERE "SALIENCE" > 0.003;

SELECT COUNT(*) FROM "AIS_DEMO"."GDELT_GEG_EDGES";

-- The networks' vertices are simply projected from the V_GEG_EDGES view
CREATE OR REPLACE VIEW "AIS_DEMO"."V_GDELT_GEG_VERTICES" AS (
	SELECT "ID", MAX("NAME") AS "NAME", MAX("TYPE") AS "TYPE" FROM ( 
	SELECT "SOURCE" AS "ID", "SOURCE_NAME" AS "NAME", "SOURCE_TYPE" AS "TYPE" FROM "AIS_DEMO"."GDELT_GEG_EDGES"
	UNION
	SELECT "TARGET" AS "ID", "TARGET_NAME" AS "NAME", "TARGET_TYPE" AS "TYPE" FROM "AIS_DEMO"."GDELT_GEG_EDGES"
	) GROUP BY "ID"
);

-- And finally we create a Graph Workspace
CREATE GRAPH WORKSPACE "AIS_DEMO"."GRAPH_GEG"
	EDGE TABLE "AIS_DEMO"."GDELT_GEG_EDGES"
		SOURCE COLUMN "SOURCE"
		TARGET COLUMN "TARGET"
		KEY COLUMN "ID"
	VERTEX TABLE "AIS_DEMO"."V_GDELT_GEG_VERTICES" 
		KEY COLUMN "ID";



	
	
	
	
	