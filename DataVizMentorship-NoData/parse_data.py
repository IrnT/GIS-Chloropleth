import json
import geopandas as gpd
import pandas as pd
import numpy as np

# GLOBAL VARIABLES
avg_resource_reach = 62.5  # How many voters each canvasser reaches
chance_turnout = 0.09  # Percent of reached voters convinced to vote
registered_voters = 703021  # Total registered voters in county
county_wide_turnout = 0.8409  # Election turnout
ccc = 581230  # Votes cast in Contra Costa
county_wide_dem_npp_percent = 0.7501  # Combined percentage of Dem + NPP voters county-wide

# Load and transform the shapefile
full_path = "..."
path_ca = f"{full_path}/ca_2020.shp"
data_ca = gpd.read_file(path_ca).to_crs(epsg=4326)

# Data Processing: Filtering & Mutating
de_saulnier = (
    data_ca[data_ca["COUNTY"] == "Contra Costa"]
    .assign(
        NumCanvassers=0,
        Precinct=lambda df: df["SRPREC"],
        Dem=lambda df: df["G20PREDBID"],
        Rep=lambda df: df["G20PRERTRU"],
        Liber=lambda df: df["G20PRELJOR"],
        Green=lambda df: df["G20PREGHAW"],
        AmerIndep=lambda df: df["G20PREAFUE"],
        PeaceFreedom=lambda df: df["G20PREPLAR"],
    )
    .drop(columns=["COUNTY", "CNTY_CODE", "FIPS_CODE", "SRPREC_KEY", "ADDIST", "SDDIST", "BEDIST"])
)

# Computing additional fields
de_saulnier["DemVoteShare"] = de_saulnier["Dem"] / (
    de_saulnier["Dem"]
    + de_saulnier["Rep"]
    + de_saulnier["Liber"]
    + de_saulnier["Green"]
    + de_saulnier["AmerIndep"]
    + de_saulnier["PeaceFreedom"]
)
de_saulnier["PrecinctVotes"] = (
    de_saulnier["Dem"]
    + de_saulnier["Rep"]
    + de_saulnier["Liber"]
    + de_saulnier["Green"]
    + de_saulnier["AmerIndep"]
    + de_saulnier["PeaceFreedom"]
)
de_saulnier["PercVotersInPrecinct"] = de_saulnier["PrecinctVotes"] / ccc

# Avoid division errors by replacing NaN with 0
de_saulnier["DemVoteShare"] = de_saulnier["DemVoteShare"].fillna(0)

# Calculate estimated DidNotVoteDemNPP
de_saulnier["DidNotVoteDemNPP"] = np.round(
    de_saulnier["PercVotersInPrecinct"]
    * registered_voters
    * (1 - county_wide_turnout)
    * county_wide_dem_npp_percent
)

# Filtering for district 11 and dropping column
de_saulnier = de_saulnier[de_saulnier["CDDIST"] == 11].drop(columns=["CDDIST"])

# Convert DataFrame to GeoJSON format
geojson_data = {
    "type": "FeatureCollection",
    "features": []
}

for _, row in de_saulnier.iterrows():
    feature = {
        "type": "Feature",
        "geometry": row["geometry"].__geo_interface__,  # Convert geometry to GeoJSON format
        "properties": {
            "precinct": row["Precinct"],
            "dem_vote_share": row["DemVoteShare"],
            "precinct_votes": row["PrecinctVotes"],
            "perc_voters_in_precinct": row["PercVotersInPrecinct"],
            "did_not_vote_dem_npp": row["DidNotVoteDemNPP"]
        }
    }
    geojson_data["features"].append(feature)

# Save as JSON file
output_path = f"{full_path}/de_saulnier.json"
with open(output_path, "w") as json_file:
    json.dump(geojson_data, json_file, indent=4)

print(f"JSON file saved successfully at {output_path}!")