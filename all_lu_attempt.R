# These functions are for getting the network data for the street profile analysis tutorial ()
# You will need the following packages:
library(rjson)
library(dplyr)
library(sf)


# get list of valid tube line names
get_lines <- fromJSON(readLines("https://api.tfl.gov.uk/Line/Mode/tube/Route"))

datalist <- list()
for (i in 1:length(get_lines)) {

  datalist[i] <- get_lines[[i]]$id

}

all_lines <- unlist(datalist)



#function to get stops
getLineStops <- function(linename){

  #get json from TfL API
  api_call <- fromJSON(readLines(paste0("https://api.tfl.gov.uk/line/",linename,"/route/sequence/outbound")))

  #parse df of stops and latlongs
  datalist = list()
  for (i in 1:length(api_call$stations)) {

    datalist[[i]] <- data.frame(stn_name = api_call$stations[[i]]$name,
                                stn_lat = api_call$stations[[i]]$lat,
                                stn_lon = api_call$stations[[i]]$lon,
                                line = "bakerloo")
  }
  line_stops <- do.call(rbind, datalist)



  return(st_as_sf(line_stops, coords = c("stn_lon", "stn_lat"), crs = 4326))


}

# test for bakerloo line
bakerloo_stops <- getLineStops("bakerloo")


#function to bind bakerloo line stops into line

getLine <- function(x){

  return(x %>% group_by(line) %>% st_union() %>% st_cast("LINESTRING"))

}


bakerloo_line <- getLine(bakerloo_stops)

# try for all lines
datalist <- list()
for (i in 1:length(all_lines)){
  datalist[[i]] <- data.frame(name = all_lines[i],
                              line_geom = getLine(getLineStops(all_lines[i])))
}
 all_lu <- do.call(rbind, datalist)

 # this is a df (even though has geometry col)
class(all_lu)


# TODO:
# make sf bject
# slice at points

# code to slice at points for bakerloo line example:
# library(lwgeom)
#
# parts <- st_split(bakerloo_line, st_combine(bakerloo_stops$geometry)) %>% st_collection_extract("LINESTRING")
#
# datalist = list()
# for (i in 1:length(parts)) {
#
#   datalist[[i]] <- st_as_sf(data.frame(section = i), geometry = st_geometry(parts[i]))
#
# }
#
# bakerloo_sections <- do.call(rbind, datalist)
