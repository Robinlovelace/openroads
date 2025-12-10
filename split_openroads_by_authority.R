# Load necessary libraries
library(sf)
library(dplyr)

# Paths
input_gpkg = "data_raw/Data/oproad_gb.gpkg"
authorities_geojson = "data_raw/transport_authorities_2025.geojson"
output_dir = "openroads"

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

# 1. Read Authorities Data
message("Reading Authorities GeoJSON...")
authorities = read_sf(authorities_geojson)

# 2. Determine CRS of OpenRoads data
message("Determining OpenRoads CRS...")
# Read a single row to get CRS
# Using a limit query if possible, or just reading head
sample_or = read_sf(input_gpkg, layer = "road_link", query = "SELECT * FROM road_link LIMIT 1")
or_crs = st_crs(sample_or)
message(paste("OpenRoads CRS:", or_crs$input))

# 3. Iterate and Subset
total_authorities = nrow(authorities)

for (i in 1:total_authorities) {
  auth = authorities[i, ]
  auth_name = auth$name
  
  # Sanitize filename
  safe_name = gsub("[^a-zA-Z0-9]+", "_", auth_name)
  safe_name = gsub("^_|_$", "", safe_name) # Trim leading/trailing underscores
  output_file = file.path(output_dir, paste0(safe_name, ".gpkg"))
  
  message(paste0("[", i, "/", total_authorities, "] Processing: ", auth_name, " -> ", output_file))
  
  if (file.exists(output_file)) {
    message("  File exists, skipping.")
    next
  }
  
  # Transform authority geometry to OpenRoads CRS
  auth_geom = st_geometry(auth)
  # Check validity
  if (any(!st_is_valid(auth_geom))) {
     message("  Fixing invalid geometry...")
     auth_geom = st_make_valid(auth_geom)
  }

  auth_transformed = st_transform(auth_geom, or_crs)
  
  # Convert to WKT for filter
  wkt_filter_str = st_as_text(auth_transformed)
  
  # Read with spatial filter
  tryCatch({
    subset_data = read_sf(input_gpkg, layer = "road_link", wkt_filter = wkt_filter_str)
    
    if (nrow(subset_data) == 0) {
      message("  No roads found within this boundary.")
    } else {
      message(paste("  Writing", nrow(subset_data), "features..."))
      write_sf(subset_data, output_file)
    }
  }, error = function(e) {
    message(paste("  Error reading/writing data:", e$message))
  })
}

message("All processing complete.")
