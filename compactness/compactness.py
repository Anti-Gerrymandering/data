"""
run `python compactness.py path/to/geojson_files/*.geojson`
"""

import numpy as np
import geopandas as gp
import json

from sys import argv
from glob import glob

"""
Parameters
---------
geo_df : Geopandas dataframe

Returns
-------
compactness : Geopandas dataframe
"""
def compactness(geo_df):
    return (4 * np.pi * geo_df.area) / np.power(geo_df.length, 2)

if __name__ == "__main__":
    list_of_geojson_files = glob(argv[1])
    for f in list_of_geojson_files:
        set_of_geos = gp.read_file(f)
        compactness_series = compactness(set_of_geos)
        # print(compactness_df)
        set_of_geos.loc[:, 'Compactness'] = compactness_series
        gjson = set_of_geos.to_json()
        with open(f, 'w') as gjson_file:
            gjson_file.write(gjson)
