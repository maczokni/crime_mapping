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
