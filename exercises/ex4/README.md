# Exercise 4 - Spatial Clustering

In this exercise, we will use spatial clustering techniques to understand density and spatial distribution of AIS observations.
There a some different techniques to cluster points - (rectangular) grid, hexagon, DBScan, and KMeans. See the [SAP HANA Cloud Spatial Reference](https://help.sap.com/viewer/bc9e455fe75541b8a248b4c09b086cf5/2021_3_QRC/en-US/7eb3c0e6bbf04fc6bcb9809d81533e6f.html).
For all variants, there is a native SQL syntax: GROUP CLUSTER BY. For hexagon clustering with 400 cells in Y direction it looks like this:

```SQL
SELECT ST_CLUSTERID() AS "ID", ST_CLUSTERCELL() AS "SHAPE", COUNT(*) AS C, COUNT(DISTINCT "MMSI") AS "SHIPS"
	FROM "AIS_DEMO"."AIS_2017"
	GROUP CLUSTER BY "SHAPE_32616" USING HEXAGON Y CELLS 400;
```

We can use spatial clusters to understand the density of cargo vessel observations. We see that cargo ship are manly travelling the north-south route.
<br>![](images/clustering_cargo.png)

For passenger ships, the distribution looks different - here we see mainly east-west traffic.

![](images/clustering_passenger.png)

## Summary

We have introduced basic spatial clustering.

Continue to - [Exercise 5 - Vessel Routes ](../ex5/README.md)
