# DAT262 - Unlock Value and Gain Deep Insights from Your Data with SAP HANA Cloud

## Description

This repository contains the material for the SAP TechEd 2021 session called DAT262 - Unlock Value and Gain Deep Insights from Your Data with SAP HANA Cloud.  

## Overview

This session introduces attendees to the **multi-model** capabilities in SAP HANA Cloud. We will mainly work with data from the Automatic Identification System (**AIS**), which is basically observations in space and time. In specific, we will process AIS vessel data which is provided by [https://marinecadastre.gov/ais/](https://marinecadastre.gov/ais/). Files covering two months of "Zone 16" (Chicago, Great Lakes) are imported into SAP HANA Cloud and Lon/Lat coordinates are converted to a "real" point geometry.</br>
In exercises 1-3, the data is processed using standard SQL/**spatial functions** to 1 check which vessels were crossing boundaries of a national park, 2 derive motion statistics and trajectories of individual vessels, and 3 aggregate observations using spatial clustering techniques.</br>
We will then calculate routes using **graph capabilities** (4), this includes the simulated blockage of a ship canal and the identification of a suitable alternative route.</br>
In exercise 5 and 6, we will show how to use an extension of spatial clustering to derive a "Space-Time Cube". The resulting dataset is then used to forecast traffic (7) on the lake using HANA's built-in "Predictive Analysis Library" (**PAL**).</br>
...

## Requirements

Most of the spatial and graph related exercises can be run on a SAP HANA Cloud trial instance, but for the PAL and JSON Document Store related capabilities you currently would need to work with a "full" SAP HANA Cloud system.

## Exercises
A copy of the demo data and all scripts are located in the [data_and_script folder](exercises/data_and_script).

- [Getting Started](exercises/ex0/)
    - [Base Data & Demo Scenario](exercises/ex0#subex1)
    - [SAP HANA Cloud setup](exercises/ex0#subex2)
    - [DBeaver, QGIS, hana-ml, Cytoscape](exercises/ex0#subex3)
    - [Background Material](exercises/ex0#subex4)
- [Exercise 1 - Prepare the Data](exercises/ex1/)
    - [Exercise 1.1 - Import the Raw Data](exercises/ex1#subex1)
    - [Exercise 1.2 - Generate Geometries](exercises/ex1#subex2)
    - [Exercise 1.3 - Remove Duplicates](exercises/ex1#subex3)
- [Exercise 2 - Identify Vessels within National Park Boundaries](exercises/ex2/)
    - [Exercise 2.1 - Use ST_Within(), ST_MakeLine(), and ST_CollectAggr()](exercises/ex2#subex2)
- [Exercise 3 - Understand Vessel Motion](exercises/ex3/)
    - [Exercise 3.1 - Derive Speed, Acceleration, Total Distance, and Total Time](exercises/ex3#subex1)
    - [Exercise 3.2 - Vessel Trajectories](exercises/ex3#subex2)
    - [Exercise 3.3 - Dwell Locations and Trip Segments](exercises/ex3#subex3)
- [Exercise 4 - Spatial Clustering](exercises/ex4/)
- [Exercise 5 - Vessel Routes](exercises/ex5/)
    - [Exercise 5.1 - Generate a Network for Path Finding](exercises/ex5#subex1)
    - [Exercise 5.2 - Use Shortest Path with a Custom Cost Function](exercises/ex5#subex2)
    - [Exercise 5.3 - Simulate a Canal Blockage and Find Alternative Routes](exercises/ex5#subex3)
- [Exercise 6 - Spatio-Temporal Clustering](exercises/ex6/)
- [Exercise 7 - Predict Traffic](exercises/ex7/)
    - [Exercise 7.1 - Create Space-Time Cube](exercises/ex7#subex1)
    - [Exercise 7.2 - Timeseries Forecasting using Massive Auto Exponential Smoothing](exercises/ex7#subex2)
- [Exercise 8 - Enterprise Search](exercises/ex8/)
- [Exercise 9 - Document Store and Graph](exercises/ex9/)
    - [Exercise 9.1 - Load JSON data via Python Client for Machine Learning (hana-ml)](exercises/ex9#subex1)
    - [Exercise 9.2 - Generate a Graph and Visualize in Cytoscape](exercises/ex9#subex2)

## How to obtain support

Support for the content in this repository is available during the actual time of the online session for which this content has been designed. Otherwise, you may request support via the [Issues](../../issues) tab.

## License
Copyright (c) 2021 SAP SE or an SAP affiliate company. All rights reserved. This project is licensed under the Apache Software License, version 2.0 except as noted otherwise in the [LICENSE](LICENSES/Apache-2.0.txt) file.
