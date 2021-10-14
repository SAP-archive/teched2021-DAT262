# Getting Started

This section should give you an understanding of the base scenario and base data. Additionally, we will describe the SAP HANA Cloud setup in case you want to run the exercises yourself. As we will process the data using SQL, the SQL editor of SAP HANA Database Explorer (DBX) is sufficient. However, for the "full experience" we recommend DBeaver, QGIS (or Esri ArcGIS Pro) for spatial, cytoscape for graph visualizations, and Jupyter notebooks to work with the hana-ml python library for machine learning. At the end of the section, you will find links to additional information on SAP HANA Cloud Multi-Model.

## Base Data & Demo Scenario<a name="subex1"></a>

**Space-Time observations**, i.e. geo-locations with a timestamp, are found in many scenarios, e.g. transportation and logistics, health and sports (fitness tracker), public security, environmental analysis. The Automatic Identification System (**AIS**) **vessel data** we use in the exercises are such space-time observations. The raw data is collected by the U.S. Coast Guard through an onboard navigation safety device. It has been obtained from [https://marinecadastre.gov/ais/](https://marinecadastre.gov/ais/) and can be downloaded in form of flat files. The data contains Lon/Lat coordinates, a timestamp, and information about the vessel like vesseltype, name, callsign etc. The granularity of the data has been changing in the recent years. For simplicity reasons, we chose to work with data from 2017 (May and June), covering [UTM Zone 16](https://marinecadastre.gov/AIS/AIS%20Documents/UTMZoneMap2014.png), which includes the area around lake Michigan. The processing and analysis patterns described in the exercises include
<ul>
<li>identify vessels that went through certain areas
<li>derive motion statistics like speed, acceleration, and heading
<li>calculate individual vessel trajectories
<li>finding suitable alternative routes in case of a blockage
<li>forecasting traffic based on space-time aggregation
</ul>

Second scenario using GDLET data...

## SAP HANA Cloud setup<a name="subex2"></a>

Most of the exercises and processing patterns can be run on a free SAP HANA Cloud trial system. To get one, visit [SAP HANA Cloud Trial home](https://www.sap.com/cmp/td/sap-hana-cloud-trial.html). To run timeseries forecasting and work with JSON data using the Document Store, you will need a full SAP HANA Cloud. Make sure to provision PAL and Document Store **!!! LINKS REUQIRED!!!**
Your HANA database user requires some roles and privileges
<ul><li>roleAFL PAL EXECUTE to execute PAL algorithms
<li>sys privCERTIFICATE ADMIN, TRUST ADMIN, IMPORT to prepare and run data uploads from S3
<li>obj priv ESH_CONFIG and ESH_SEARCH for creating search models and running search queries
</ul>

## DBeaver, QGIS, python, and Cytoscape<a name="subex3"></a>

The SAP HANA Database Explorer provides a SQL editor, table viewer and data analysis tools, and a simple graph viewer. For a "full experience" we have used the following tools in addition.

**DBeaver**<br>an open source database administration and development tool. You can run the SQL script in DBeaver and get simple spatial visualizations. See Mathias Kemeters blog for [installation instructions](https://blogs.sap.com/2020/01/08/good-things-come-together-dbeaver-sap-hana-spatial-beer/).

**QGIS**<br>an open source Geographical Information System (GIS). QGIS can connect to SAP HANA and provides great tools for advanced maps. Again, read Mathias' blog to [get it up and running](https://blogs.sap.com/2021/03/01/creating-a-playground-for-spatial-analytics/).

**hana-ml**, Jupyter Notebook<br>we used the python machine learning client for SAP HANA and Jupyter Notebooks to load JSON data into the document store. There is a lot in hana-ml for the data scientist - see [pypi.org](https://pypi.org/project/hana-ml/)

**Cytoscape**<br>for advanced graph visualization you can pull data from a Graph Workspace into Cytoscape using... Kemeter... name sounds familiar... anyhow, see this post to get an unsupported preview version of the [Cytoscape HANA plug-in](https://blogs.sap.com/2021/09/22/explore-networks-using-sap-hana-and-cytoscape/).

##  Background Material<a name="subex4"></a>

[SAP HANA Spatial Resources](https://blogs.sap.com/2020/11/02/sap-hana-spatial-resources-reloaded/)<br>
[SAP HANA Graph Resources](https://blogs.sap.com/2021/07/21/sap-hana-graph-resources/)<br>
[SAP HANA Machine Learning Resources](https://blogs.sap.com/2021/05/27/sap-hana-machine-learning-resources/)

## Summary

You are all set...

Continue to - [Exercise 1 - Preparing the Data](../ex1/README.md)
