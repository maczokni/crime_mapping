
library(readr)
library(dplyr)
library(ggplot2)
library(osmdata)
library(sf)
library(spatstat)
library(raster)
library(leaflet)



# making cover image, but need to get week 2 stuff into environment

#read csv data
comisarias <- read_csv("data/nationalpolice.csv")
#set crs, read into sf object, and assign crs
polCRS <- st_crs(4326)
comisarias_sf <- st_as_sf(comisarias, coords = c("X", "Y"), crs = polCRS)

#create unique id for each row
comisarias_sf$id <- as.numeric(rownames(comisarias_sf))

#Read as sf boundary data for Madrid city
madrid <- st_read("data/madrid.geojson")

madrid_metres <- st_transform(madrid, crs = 2062)

madrid_grid <- st_make_grid(madrid_metres,  cellsize = 250)

#only extract the points in the limits of Madrid
madrid_grid <- st_intersection(madrid_grid, madrid_metres)

comisarias_sf_metres <- st_transform(comisarias_sf, crs = 2062)

distances <- st_distance(comisarias_sf_metres,
                         st_centroid(madrid_grid)) %>%
  as_tibble()

# Compute distances
police_distances <- data.frame(
  # We want grids in a WGS 84 CRS:
  us = st_transform(madrid_grid, crs = 4326),
  # Extract minimum distance for each grid
  distance_km = purrr:::map_dbl(distances, min)/1000,
  # Extract the value's index for joining with the location info
  location_id = purrr:::map_dbl(distances, function(x) match(min(x), x))) %>%
  # Join with the police station table
  left_join(comisarias_sf, by = c("location_id" = "id"))


police_distances$distance_m <- round(police_distances$distance_km*1000, 0)

# Create more appropriate icon, taking it from Wikipedia commons
icon_url_pt1 <- "https://upload.wikimedia.org/wikipedia/commons/"
icon_url_pt2 <- "a/ad/189-woman-police-officer-1.svg"

# create icon, adjusting size
police_icon <- makeIcon(paste0(icon_url_pt1, icon_url_pt2),
                        iconWidth = 12, iconHeight = 20)

# Bin ranges for a nicer color scale
bins <- round(quantile(police_distances$distance_m),0)
# Create a binned color palette
pal <- colorBin(c("#511215", "#972127", "#D3363E", "#E17A7F", "#F0BCC0"),
                domain = police_distances$distance_m,
                bins = bins,
                reverse = TRUE)

m <- leaflet() %>%
  addTiles() %>%
  addMarkers(data = comisarias_sf, icon = ~police_icon,
             group = "Police stations") %>%
  addPolygons(data = police_distances[[1]],
              fillColor = pal(police_distances$distance_m),
              fillOpacity = 0.8, weight =0, opacity = 1, color = "transparent",
              group = "Distances",
              highlight = highlightOptions(weight = 2.5, color = "#666",
                                           bringToFront = TRUE, opacity= 1),
              popupOptions = popupOptions(autoPan = FALSE, closeOnClick = TRUE,
                                          textOnly = T)) %>%
  addLegend(pal = pal, values = (police_distances$distance_m),
            opacity = 0.8, title = "Distance from police station (m)", position= "bottomright")

mapview::mapshot(m, file = "coverimg1.png",
                 zoom = 25)

#  Make the wirral cover image



highways_heswall <- opq("Heswall, UK") %>%
  add_osm_feature(key = "highway") %>%
  osmdata_sf()

heswall_lines <- highways_heswall$osm_lines

# read in asb data
shoplifting <- read_csv("data/merseyside_shoplifting.csv")

# transform to spatial object
shoplifting_sf <- st_as_sf(shoplifting,
                           coords = c("longitude", "latitude"),
                           crs = 4326)
# transform to match projection of lines
shoplifting_sf <- st_transform(shoplifting_sf, crs = st_crs(heswall_lines))

# create a bounding box around the heswall lines geometry
heswall_bb <- st_bbox(heswall_lines) %>% st_as_sfc()
# subset using the bounding box
heswall_shoplifting <- st_intersection(shoplifting_sf, heswall_bb)

# create a df of one central point
heswall_tc <- data.frame(longitude = -3.1025683,
                         latitude = 53.3281041)

# create a buffer by making point into sf object
heswall_tc_buffer <- st_as_sf(heswall_tc,
                              coords = c("longitude", "latitude"),
                              crs = 4326) %>%
  st_transform(., 27700) %>% # project to BNG (for metres)
  st_buffer(., 500)  # build 1km buffer

heswall_lines <- st_transform(heswall_lines, 27700)
heswall_shoplifting <- st_transform(heswall_shoplifting, 27700)


heswall_tc <- st_intersects(heswall_tc_buffer, heswall_lines)
heswall_tc <- heswall_lines[unlist(heswall_tc),]
# select shoplifting incidents in town centre
tc_shoplifting <- st_intersects(heswall_tc_buffer, heswall_shoplifting)
tc_shoplifting <- heswall_shoplifting[unlist(tc_shoplifting),]

ggplot() +
  geom_sf(data = heswall_tc,
          col = "#FFFFFF",
          linewidth = 0.6,
          alpha = 0.99) +
  # geom_sf(
  #   data = heswall_tc_buffer,
  #   col = "#FFFFFF",
  #   fill = NA,
  #   linewidth = 0.25,
  #   alpha = 0.75
  # ) +
  # geom_sf(
  #   data = heswall_tc_buffer,
  #   col = NA,
  #   fill = "#FFFFFF",
  #   alpha = 0.1
  # ) +
  geom_sf(data = tc_shoplifting, col = "#be8d6f", size = 5) +
  theme_void() +
  theme(panel.background = element_rect(fill = "#3d1415",
                                        colour = "#3d1415"))



thing <- st_jitter(tc_shoplifting, factor = 0.1) %>%
  mutate(x = st_coordinates(.)[,1],
         y = st_coordinates(.)[,2])

ggplot() +
  geom_sf(
    data = heswall_tc,
    col = "#FFFFFF",
    linewidth = 0.6,
    alpha = 0.99
  ) +
  geom_sf(data = st_jitter(tc_shoplifting, factor = 0.1),
          col = "#fd8d3c",
          size = 2.5) +
  theme_void() +
  theme(panel.background = element_rect(fill = "#511215",
                                        colour = "#511215"),
        legend.position = "none") +
  scale_fill_distiller(palette = 'YlOrRd')


ggsave("coverimage2.png", units="in", width=5, height=4, dpi=300)





