# Load necessary libraries
library(sf)
library(dplyr)

# 1. Download OpenRoads Data
# URL for Great Britain coverage in GeoPackage format
u = "https://api.os.uk/downloads/v1/products/OpenRoads/downloads?area=GB&format=GeoPackage&redirect"
zip_file = "open_roads.zip"

if (!file.exists(zip_file)) {
  message("Downloading OpenRoads data... (this may take a while)")
  download.file(u, zip_file, mode = "wb")
} else {
  message("File already downloaded.")
}

# 2. Unzip
extract_dir = "data_raw"
if (!dir.exists(extract_dir)) {
  message("Unzipping archive...")
  unzip(zip_file, exdir = extract_dir)
}

# 3. Import
# Locate the .gpkg file within the extracted folder
gpkg_path = list.files(extract_dir, pattern = "oproad.*\.gpkg$", recursive = TRUE, full.names = TRUE)[1]

if (is.na(gpkg_path)) {
  stop("Could not find OpenRoads .gpkg file in the extracted directory.")
}

message(paste("Reading road links from:", gpkg_path))
# The main layer is usually 'road_link'
open_roads = read_sf(gpkg_path, layer = "road_link")

# 4. Subset
# Example: Subsetting for a specific region (e.g., Leeds)
# Define a bounding box for Leeds
message("Subsetting for Leeds area...")
leeds_bbox = st_bbox(c(xmin = -1.65, ymin = 53.75, xmax = -1.45, ymax = 53.85), crs = 4326)
leeds_poly = st_as_sfc(leeds_bbox)

# Ensure CRS matches
if (st_crs(open_roads) != st_crs(leeds_poly)) {
  leeds_poly = st_transform(leeds_poly, st_crs(open_roads))
}

# Spatial subset
open_roads_leeds = open_roads[leeds_poly, ]

message(paste("Original features:", nrow(open_roads)))
message(paste("Subset features:", nrow(open_roads_leeds)))

# 5. Save the subset
output_file = "open_roads_leeds.gpkg"
message(paste("Saving subset to", output_file))
write_sf(open_roads_leeds, output_file)

message("Done.")

