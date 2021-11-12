/***************************************/
-- # Exercise 8 - Enterprise Search
/***************************************/

-- We first create a view that identifies each vessel's last position
CREATE OR REPLACE VIEW "AIS_DEMO"."V_VESSEL_LAST_POSITION" AS (
	SELECT "MMSI", "SHAPE_32616".ST_TRANSFORM(4326) AS "LOC_4326", "SHAPE_32616".ST_TRANSFORM(3857) AS "LOC_3857" FROM (
	SELECT "MMSI", "SHAPE_32616", RANK() OVER(PARTITION BY "MMSI" ORDER BY "TS" DESC) AS R FROM "AIS_DEMO"."AIS_2017"
	) WHERE R = 1
);

-- ... and store the results in a table
CREATE COLUMN TABLE "AIS_DEMO"."VESSELS" (
	"MMSI" INT, 
	"VESSELNAME" NVARCHAR(100), 
	"IMO" NVARCHAR(500), 
	"CALLSIGN" NVARCHAR(500), 
	"VESSELTYPE_CODE" INT, 
	"VESSELTYPE" NVARCHAR(100),
	"LOC_4326" ST_POINT(4326), 
	"LOC_3857" ST_POINT(3857), 
	"WIDTH" DOUBLE, 
	"CARGO" DOUBLE
);

INSERT INTO "AIS_DEMO"."VESSELS"
	SELECT DAT."MMSI", "VESSELNAME", "IMO", "CALLSIGN", DAT."VESSELTYPE" AS "VESSELTYPE_CODE", CODES."TEXT" AS "VESSELTYPE", 
		POS."LOC_4326", POS."LOC_3857", "WIDTH", MAX("CARGO") AS "CARGO" 
		FROM "AIS_DEMO"."AIS_2017" AS DAT 
		LEFT JOIN "AIS_DEMO"."VESSELTYPE_TEXT" AS CODES ON DAT."VESSELTYPE" = CODES."CODE"
		LEFT JOIN "AIS_DEMO"."V_VESSEL_LAST_POSITION" AS POS ON DAT."MMSI" = POS."MMSI"
		WHERE "VESSELNAME" IS NOT NULL
		GROUP BY DAT."MMSI", "VESSELNAME", "IMO", "CALLSIGN", DAT."VESSELTYPE", CODES."TEXT", POS."LOC_4326", POS."LOC_3857", "WIDTH";

-- ... and put a nice view on top that exposes the data we want to search and display in a result
CREATE OR REPLACE VIEW "AIS_DEMO"."V_ESH_VESSELS" AS (
	SELECT "MMSI", "VESSELNAME", "IMO", "CALLSIGN", "VESSELTYPE_CODE", "VESSELTYPE", 
		"LOC_4326".ST_ASGEOJSON() AS "LOC_4326", "LOC_3857" AS "LOC", "WIDTH", "CARGO"
		FROM AIS_DEMO.VESSELS
);

SELECT * FROM "AIS_DEMO"."V_ESH_VESSELS" ORDER BY RAND();

CALL ESH_CONFIG('
[{"uri":    "~/$metadata/EntitySets", "method": "PUT",
"content":{ 
"Fullname": "AIS_DEMO/V_ESH_VESSELS",
"EntityType": {
	"@Search.searchable": true,
	"@EnterpriseSearch.enabled": true,
	"@SAP.Common.Label": "Vessels",
	"@UI.headerInfo.title": {"value": "VESSELNAME"},
	"@UI.headerInfo.typeName": "Vessel",
	"@UI.headerInfo.typeNamePlural": "Vessels",
	"@EnterpriseSearchHana.passThroughAllAnnotations":true,
	"@EnterpriseSearchHana.processing.ignoreInvalidSearchOptions": true,
"Properties": [
{
	"Name": "MMSI",
	"@UI.identification": { "position": 1 },
	"@EnterpriseSearch.key": true,
	"@Search.defaultSearchElement": true
},{
    "Name": "VESSELNAME",
	"@UI.identification": { "position": 2 },
    "@EnterpriseSearch.highlighted.enabled": true,
    "@Search.defaultSearchElement": true,
    "@EnterpriseSearch.defaultValueSuggestElement": true,
    "@Search.fuzzinessThreshold": 0.8,
    "@EnterpriseSearch.searchOptions": "similarCalculationMode=substringsearch"
},{
	"Name": "VESSELTYPE",
	"@UI.identification": { "position": 3 },
	"@EnterpriseSearch.highlighted.enabled": true,
	"@Search.defaultSearchElement": true,
	"@EnterpriseSearch.filteringFacet.default": true,
	"@EnterpriseSearch.filteringFacet.displayPosition": 1,
	"@Search.fuzzinessThreshold": 0.8,
	"@EnterpriseSearch.searchOptions": "similarCalculationMode=substringsearch"
},{
	"Name": "CALLSIGN",
	"@UI.identification": { "position": 4 },
	"@EnterpriseSearch.highlighted.enabled": true,
	"@Search.defaultSearchElement": true,
	"@Search.fuzzinessThreshold": 0.8
},{
    "Name": "IMO",
	"@UI.identification": { "position": 5 },
    "@EnterpriseSearch.highlighted.enabled": true,
    "@Search.defaultSearchElement": true,
    "@Search.fuzzinessThreshold": 0.8
},{
    "Name": "LOC_4326",
	"@UI.identification": { "position": 10 }
},{
    "Name": "WIDTH",
    "@Search.defaultSearchElement": false,
    "@EnterpriseSearch.filteringFacet.default": true,
    "@EnterpriseSearch.filteringFacet.displayPosition": 2,
    "@UI.identification": { "position": 6 }
},{
	"Name": "CARGO",
	"@Search.defaultSearchElement": false,
	"@EnterpriseSearch.filteringFacet.default": true,
	"@EnterpriseSearch.filteringFacet.displayPosition": 3,
	"@UI.identification": { "position": 7 }
}
]}}}]',?);

CALL SYS.ESH_SEARCH('["/v20411/AIS_DEMO/$metadata"]', ?);
CALL SYS.ESH_SEARCH('["/v20411/AIS_DEMO/$all?$filter=Search.search(query=''ann'')" ]', ?);
CALL SYS.ESH_SEARCH('["/v20411/AIS_DEMO/$all?%24count=true&%24top=10&%24skip=0&%24apply=filter(Search.search(query%3D%27SCOPE%3AV_ESH_VESSELS%20%20(ann%20pleasure)%27))&whyfound=true&facets=all&facetlimit=5"]', ?);





