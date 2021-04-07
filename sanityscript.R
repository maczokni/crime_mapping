##JUST a script to try out things when they seem broken

crimes <- read.csv("https://raw.githubusercontent.com/maczokni/2018_labs/master/data/2017-11-greater-manchester-street.csv")
#The following assumes you have a subdirectory called BoundaryData in your working directory, otherwise you will need to change to the pathfile where you store your LSOA shapefile
shp_name <- "data/BoundaryData/england_lsoa_2011.shp"
manchester_lsoa <- st_read(shp_name)
crimes_per_lsoa <- crimes %>%
  select(LSOA.code) %>%
  group_by(LSOA.code) %>%
  summarise(count=n())
manchester_lsoa <- left_join(manchester_lsoa, crimes_per_lsoa, by = c("code"="LSOA.code"))
census_lsoa_m <- read_csv("https://www.dropbox.com/s/e4nkqmefovlsvib/Data_AGE_APPSOCG_DAYPOP_UNIT_URESPOP.csv?dl=1")
census_lsoa_m <- slice(census_lsoa_m, 3:284)
census_lsoa_m <- select(census_lsoa_m, GEO_CODE, F996:F323339)
census_lsoa_m[2:9] <- lapply(census_lsoa_m[2:9], as.numeric)
census_lsoa_m <- rename(census_lsoa_m, tothouse = F996, notdepr = F997, depriv1 = F998,
                        depriv2 = F999, depriv3 = F1000, depriv4 = F1001, respop = F2384,
                        wkdpop = F323339)
manchester_lsoa <- left_join(manchester_lsoa, census_lsoa_m, by = c("code"="GEO_CODE"))
manchester_lsoa <- mutate(manchester_lsoa, crimr1 = (count/respop)*100000, crimr2 = (count/wkdpop)*100000)
manhçchester <- select(manchester_lsoa, code, count, tothouse, respop, wkdpop, geometry)
manchester <- manhçchester
class(manchester)
st_crs(manchester)
st_crs(manchester_lsoa)
st_crs(manchester) == st_crs(x)
y = st_transform(x, crs = 27700)
st_crs(y)
st_write(manchester, "data/manchester", driver = "GeoJSON")
?st_write
z <- st_read("data/manchester")
hist(manchester$crimr2)


We do indeed, as we made sure in the previous section.
Now we can move on to our spatial operation, where we select
only those points within the city centre polygon. To do this,
we first make a list of intersecting polints to the polygon,
useing the `st_intersects()` function. This function takes
two arguments, first the polygon which we want to subset our
points within, and second, the points which we want to subset.
We then use the resulting `cc_crimes` object to subset the crimes
object to include only those which intersect (return `TRUE` for
                                              intersects):

  ```{r}
# intersection
manhattan_housing <- st_intersects(ctshp, nyc_houses)
# subsetting
manhattan_housing <- nyc_houses[unlist(manhattan_housing),]
plot(manhattan_housing)
plot(ctshp)

library(tidycensus)
census_api_key("c466e96ee65ca63b7de478ba06e94dc381c6a14d")
census_var <- load_variables(2010, "sf1", cache = TRUE)
View(census_var)
hous_units <- get_decennial(geography = "tract",
                            variables = "H001001",
                            year = 2010,
                            state = "New York",
                            county = "New York County",
                            geometry = TRUE,
                            keep_geo_vars = TRUE)
tm_shape(hous_units) +
  tm_polygons("value")
shp_name <- "data/NYC_Census_Tracts_for_2010_US_Census/NYC_Census_Tracts_for_2010_US_Census.shp"
ct <- st_read(shp_name)
tm_shape(ct) +
  tm_polygons("BoroCode")
ct_manhattan <- filter(ct, BoroCode==1)
tm_shape(ct_manhattan) +
  tm_polygons("BoroCode")
rm(ct)
summary(as.numeric(ct_manhattan$CT2010))
summary(as.numeric(hous_units$TRACT))
hous_units <- dplyr::select(hous_units, TRACT, value)
st_geometry(hous_units) <- NULL
hous_units <- rename(hous_units, CT2010 = TRACT)
ct <- merge(ct_manhattan, hous_units, by = "CT2010")
tm_shape(ct) +
  tm_polygons("value")
st_write(ct, "data/nyc/manhattan_housing.shp")


st_write(hous_units, "data/nyc/manhattan_housing.shp")
shp_name <- "data/nyc/manhattan_housing.shp"
housing <- st_read(shp_name)
housing <- st_transform(housing, 32118)
shp_name <- "data/NYC_Census_Tracts_for_2010_US_Census/NYC_Census_Tracts_for_2010_US_Census.shp"
ct <- st_read(shp_name)
ct <- st_transform(housing, 32118)
ok <- dplyr::select(housing, GEO_ID, value)
st_geometry(ok) <- NULL
please <- merge(ct,ok,by="GEO_ID")
tm_shape(please) +
  tm_polygons("value.x")
st_write(hous_units, "data/nyc/manhattan_housing.shp")

tm_shape(manhattan_housing) +
  tm_polygons("totalunits")


We do indeed, as we made sure in the previous section.  Now we can move on to our spatial operation, where we select only those points within the city centre polygon. To do this, we first make a list of intersecting polints to the polygon, useing the `st_intersects()` function. This function takes two arguments, first the polygon which we want to subset our points within, and second, the points which we want to subset. We then use the resulting `cc_crimes` object to subset the crimes object to include only those which intersect (return `TRUE` for intersects):

  ```{r}
# intersection
cc_crimes <- st_intersects(city_centre, crimes)
# subsetting
cc_crimes <- crimes[unlist(cc_crimes),]


