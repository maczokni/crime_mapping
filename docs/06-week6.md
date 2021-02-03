---
always_allow_html: true
---

# Studying spatial point patterns


## What we'll do today

We have now covered quite a bit! You've learnt about spatial objects and various formats in which they come and are stored by R, how to produce maps using a variety of packages, and also provided you with a brief introduction to common spatial operations. In what remains of the semester we are going to shift the emphasis and start focusing a bit more on spatial statistics. First we will focus on techniques that are used to explore and analyse points in a geographical space and in subsequent sessions we will cover techniques that are used to analyse spatial data when our unit of analysis are polygons (e.g., postal code areas, census areas, police beats, etc).

We will introduce a new R package called `spatstat`, that was developed for spatial point pattern analysis and modelling. It was written by Adrian Baddeley and Rolf Turner. There is a [webpage](http://spatstat.org) dedicated to this package. The [thickest book](https://www.crcpress.com/Spatial-Point-Patterns-Methodology-and-Applications-with-R/Baddeley-Rubak-Turner/p/book/9781482210200) in my library, at 810 pages, is dedicated to this package. So as you can imagine the theory and practice of spatial pattern analysis is something one could devote an entire course to. You can get a pdf document used in a course the authors of this package develop [here](https://research.csiro.au/software/wp-content/uploads/sites/6/2015/02/Rspatialcourse_CMIS_PDF-Standard.pdf). In our course we are only going to provide you with an introductory practical entry into this field of techniques. If this package is not installed in your machine, make sure you install it before we carry on.


```r
library(sf)
library(tmap)
library(dplyr)
library(spatstat)
```

## Getting the data

We will be using the crime data from Greater Manchester police we have been using so far. Let's focus on burglary in the Fallowfield area. The code below has already been explained and used in previous sessions, so we won't go over the detail again. But rather than cut and paste automatically, try to remember what each line of code is doing.

By the way, the police data for Manchester we have used in previous sessions correspond to only one month of the year. Here we are using a full year worth of data, so the data import will take a bit longer.


```r
#Read a geojson file with Manchester wards (remember we learned about geojson files in week 4)
manchester_ward <- st_read("https://raw.githubusercontent.com/RUMgroup/Spatial-data-in-R/master/rumgroup/data/wards.geojson")
```

```
## Reading layer `wards' from data source `https://raw.githubusercontent.com/RUMgroup/Spatial-data-in-R/master/rumgroup/data/wards.geojson' using driver `GeoJSON'
## Simple feature collection with 215 features and 12 fields
## geometry type:  POLYGON
## dimension:      XY
## bbox:           xmin: 351664 ymin: 381168.6 xmax: 406087.5 ymax: 421039.8
## projected CRS:  OSGB 1936 / British National Grid
```

```r
#Create a new object that only has the fallowfield ward
df1 <- manchester_ward %>%
  filter(wd16nm == "Fallowfield")

#Change coordinate systems
fallowfield <- st_transform(df1, 4326)

#Get rid of objects we no longer need
rm(manchester_ward)
rm(df1)

#Read Greater Manchester police data
crimes <- read.csv("https://raw.githubusercontent.com/jjmedinaariza/CrimeMapping/master/gmpcrime.csv")

burglary <- filter(crimes, crime_type == "Burglary")

#Transform the dataframe with crime information into a sf object
burglary_spatial = st_as_sf(burglary, coords = c("long", "lat"), 
                 crs = 4326, agr = "constant")

#Select only the crimes that take place within the space defined by the Ward boundaries
# intersection
bur_fal <- st_intersects(fallowfield, burglary_spatial)
```

```
## although coordinates are longitude/latitude, st_intersects assumes that they are planar
```

```r
# subsetting
bur_fal <- burglary_spatial[unlist(bur_fal),]
#again remove things we don't need
rm(crimes)
rm(burglary)
```

Now we have all our data cleaned and all our files prepared. Let's see the results!


```r
tm_shape(fallowfield) + 
  tm_fill() +
  tm_shape(bur_fal) +
  tm_dots()
```

<img src="06-week6_files/figure-html/unnamed-chunk-3-1.png" width="672" />

In the point pattern analysis literature each point is often referred to as an **event** and these events can have **marks**, attributes or characteristics that are also encoded in the data. In our spatial object one of these *marks* is the type of crime (altough in this case it's of little interest since we have filtered on it).

## Getting the data into spatstat: the problem with duplicates

So let's start using spatstat.The first thing we need to do is to transform our `sf` object into a `ppp` object which is how `spatstat` likes to store its point patterns. Unfortunately, spatstat and many other packages for analysis of spatial data precede sf, so the transformation is a bit awkard. Also before we do that, it is important to realise that a point pattern is defined as a series of events in a given area, or window, of observation. It is therefore extremely important to precisely define this window. In `spatstat` the function `owin()` is used to set the observation window. However, the standard function takes the coordinates of a rectangle or of a polygon from a matrix, and therefore it may be a bit tricky to use. Luckily the package `maptools` provides a way to transform a `SpatialPolygons` into an object of class `owin`, using the function `as.owin()`. Here are the steps: 


First we transform the CRS of our Falllowfield polygon into projected coordinates (British National Grid) as opposed to geographic coordinates (WGS84) :


```r
fallowfield_proj <- st_transform(fallowfield, 27700)
```



Then we use the as.owin function to define the window. 



```r
window <- as.owin(fallowfield_proj)
```



Now, use the class function and print the window object to check that this worked:


```r
class(window)
```

```
## [1] "owin"
```

```r
window
```

```
## window: polygonal boundary
## enclosing rectangle: [382951.5, 385869.8] x [393616.3, 394988.8] units
```

Now that we have created the window as an `owin` object let's get the points. First we will extract the coordinates from our sf point data into a matrix:


```r
bur_fal <- st_transform(bur_fal, 27700) #we must transform these too to match our window in BNG
sf_bur_fal_coords <- matrix(unlist(bur_fal$geometry), ncol = 2, byrow = T)
```

Then we use the `ppp` function to create the object using the information from our matrix and the window that we created.


```r
bur_ppp <- ppp(x = sf_bur_fal_coords[,1], y = sf_bur_fal_coords[,2],
                   window = window, check = T)
```

```
## Warning: data contain duplicated points
```

```r
plot(bur_ppp)
```

<img src="06-week6_files/figure-html/unnamed-chunk-8-1.png" width="672" />



Notice the warning message about duplicates. In spatial point pattern analysis an issue of significance is the presence of duplicates. The statistical methodology used for spatial point pattern processes is based largely on the assumption that processes are *simple*, that is, that the points cannot be coincident. That assumption may be unreasonable in many contexts (for example, the literature on repeat victimisation indeed suggests that we should expect the same households to be at a higher risk of being hit again). Even so the point (no pun intended) is that *"when the data has coincidence points, some statistical procedures will be severely affected. So it is always strongly advisable to check for duplicate points and to decide on a strategy for dealing with them if they are present"* (Baddeley et al., 2016: 60).

We can check the duplication in a `ppp` object with the following syntax:


```r
any(duplicated(bur_ppp))
```

```
## [1] TRUE
```

To count the number of coincidence points we use the `multiplicity()` function. This will return a vector of integers, with one entry for each observation in our dataset, giving the number of points that are identical to the point in question (including itself).


```r
multiplicity(bur_ppp)
```

If you want to know how many locations have more than one event you can use:


```r
sum(multiplicity(bur_ppp) > 1)
```

```
## [1] 190
```

That's quite something. 190 points out of 223 here share coordinates.


```r
tm_shape(fallowfield) + 
  tm_fill() +
  tm_shape(bur_fal) +
  tm_dots(alpha=0.4, size=1)
```

<img src="06-week6_files/figure-html/unnamed-chunk-12-1.png" width="672" />

In the case of crime, as we have hinted some of this may be linked to the nature of crime itself. Hint: repeat victimisation. However, this pattern of duplication is fairly obvious across all crime categories in the police.uk website.

This is due to the way in which spatial anonymisation of police.uk data is carried out. This is done using geomasking, whereby there exist a pre-determined list of points that each crime event gets "snapped" to its nearest one. So, the coordinates provided in the open data are not the exact locations of crimes, but they come from a list of points generated for purposes of data publication. You can see the details [here](https://data.police.uk/about/#anonymisation). This process is likely inflating the amount of duplication we observe, because each snap point might have many crimes near it, resulting in those crimes being geo-coded to the same exact location. So keep in mind when analysing and working with this data set that it is not the same as working with the real locations. If you are interested in the effects of this read the paper [Lisa Tompson, Shane Johnson, Matthew Ashby, Chloe Perkins & Phillip Edwards (2015) UK open source crime data: accuracy and possibilities for research, Cartography and Geographic Information Science, 42:2, 97-111, DOI: 10.1080/15230406.2014.972456](https://www.tandfonline.com/doi/abs/10.1080/15230406.2014.972456).

What to do about duplicates in spatial point pattern analysis is not always clear. You could simply delete the duplicates, but of course that may ignore issues such as repeat victimisation. You could also use jittering, which will add a small perturbation to the duplicate points so that they do not occupy the exact same space. Which again, may ignore things like repeat victimisation. Another alternative is to make each point "unique" and then attach the multiplicites of the points to the patterns as *marks*, as attributes of the points. Then you would need analytical techniques that take into account these marks.

If you were to be doing this for real you would want access to the real thing, not this public version of the data and then go for the latter solution suggested above. We don't have access to the source data, so for the sake of simplicity and so that we can illustrate how `spatstat` works we will instead add some jittering to the data. The first argument for the function is the object, `retry` asks whether we want the algorithm to have another go if the jittering places a point outside the window (we want this so that we don't loose points), and the `drop` argument is used to ensure we get a `ppp` object as a result of running this function (which we do).


```r
jitter_bur <- rjitter(bur_ppp, retry=TRUE, nsim=1, drop=TRUE)
plot(jitter_bur)
```

<img src="06-week6_files/figure-html/unnamed-chunk-13-1.png" width="672" />

Notice the difference with the original plot. Can you see how the circumferences do not overlap perfectly now?

## Inspecting our data with spatstat

This package supports all kind of exploratory point pattern analysis. One example of this is **quadrant counting**. One could divide the window of observation into quadrants and count the number of points into each of these quadrants. 
For example, if we want four quadrants along the X axis and 3 along the Y axis we could used those parameters in the `quadratcount()` function.
Then we just use standard plotting functions from R base.


```r
Q <- quadratcount(jitter_bur, nx = 4, ny = 3)
plot(jitter_bur)
plot(Q, add = TRUE, cex = 2)
```

<img src="06-week6_files/figure-html/unnamed-chunk-14-1.png" width="672" />

In the video lectures for this week, Luc Anselin  introduced the notion of **complete spatial randomness** (CSR for short). When we look at a point pattern process the first step in the process is to ask whether it has been generated in a random manner. Under CSR, points are independent of each other and have the same propensity to be found at any location. We can generate data that conform to complete spatial randomness using the *rpoispp()* function. The r at the beginning is used to denote we are simulating data (you will see this is common in R) and we are using a Poisson point process, a good probability distribution for these purposes. Let's generate 223 points in a random manner:


```r
plot(rpoispp(223))
```

<img src="06-week6_files/figure-html/unnamed-chunk-15-1.png" width="672" />

You will notice that the points in a homogeneous Poisson process are not ‘uniformly spread’: there are empty gaps and clusters of points. Run the previous command a few times. You will see the map generated is different each time.

In classical literature, the *homogeneous Poisson process* (CSR) is usually taken as the appropriate ‘null’ model for a point pattern. Our basic task in analysing a point pattern is to find evidence against CSR. We can run a Chi Square test to check this. So, for example:


```r
quadrat.test(jitter_bur, nx = 3, ny = 2)
```

```
## 
## 	Chi-squared test of CSR using quadrat counts
## 
## data:  jitter_bur
## X2 = 111.38, df = 5, p-value < 2.2e-16
## alternative hypothesis: two.sided
## 
## Quadrats: 6 tiles (irregular windows)
```

Observing the results we see that the p value is well below convential standards for rejection of the null hypothesis. Observing our data of burglary in Fallowfield would be extremely rare if the null hypothesis was true. We can then conclude that the burglary data is not randomly distributed in the observed space. But no cop nor criminologist would really question this. They would rarely be surprised by your findings! We do know that crime is not randomly distributed in space. 

## Density estimates

In the presentations by Luc Anselin and the recommended reading materials we introduced the notion of density maps. **Kernel density estimation** involves applying a function (known as a “kernel”) to each data point, which averages the location of that point with respect to the location of other data points.  The surface that results from this model allows us to produce **isarithmic maps**, also referred to in common parlor as heatmaps. Beware though, cartographers [really dislike](http://cartonerd.blogspot.com/2015/02/when-is-heat-map-not-heat-map.html) this common parlor. We saw this kind of maps when covering the various types of thematic maps. 

Kernel density estimation maps are very popular among crime analysts. According to Chainey (2012), 9 out of 10 intelligence professionals prefer it to other techniques for hot spot analysis. As compared to visualisations of crime that relies on point maps or thematic maps of geographic administrative units (such as LSOAs), kernel density estimation maps are considered best for location, size, shape and orientation of the hotspot (Chainey, 2012). [Spencer Chainey and his colleagues (2008)](http://discovery.ucl.ac.uk/112873/1/PREPRINT_-_Chainey%2C_Tompson_%26_Uhlig_2008.pdf) have also suggested that this method produces some of the best prediction accuracy. The areas identified as hotspots by KDE (using historical data) tend to be the ones that better identify the areas that will have high levels of crime in the future. Yet, producing these maps (as with any map, really) requires you to take a number of decisions that will significantly affect the resulting product and the conveyed message. Like any other data visualisation technique they can be powerful, but they have to be handled with great care.

Essentially this method uses a statistical technique (kernel density estimation) to generate a smooth continuous surface aiming to represent the density or volume of crimes across the target area. The technique, in one of its implementations (quartic kernel), is described in this way by Eck and colleagues (2005):

+ *“a fine grid is generated over the point distribution;*
+ *a moving three-dimensional function of a specified radius visits each cell and calculates weights for each point within the kernel’s radius. Points closer to the centre will receive a higher weight, and therefore contribute more to the cell’s total density value;*
+ *and final grid cell values are calculated by summing the values of all kernel estimates for each location”*

![](img/kde.png)
(Reproduced from Eck et al. 2012)

The values that we attribute to the cells in crime mapping will typically refer to the number of crimes within the area’s unit of measurement. We don’t have the time to elaborate further on this technique now, but if you did the required reading you should have at least a notion of how this works.

Let's produce one of this density maps:


```r
ds <- density(jitter_bur)
class(ds)
```

```
## [1] "im"
```

```r
plot(ds, main='Burglary density in Fallowfield')
```

<img src="06-week6_files/figure-html/unnamed-chunk-17-1.png" width="672" />

The density function is estimating a kernel density estimate. Density is nothing but the number of points per unit area. This method computes the intensity continuously across the study area and the object returns a raster image. 

To perform this analysis in R we need to define the **bandwidth** of the density estimation, which basically determines the area of influence of the estimation. There is no general rule to determine the correct bandwidth; generally speaking if the bandwidth is too small the estimate is too noisy, while if bandwidth is too high the estimate may miss crucial elements of the point pattern due to oversmoothing (Scott, 2009). 

The key argument to pass to the density method for point patterm objects is `sigma=`, which determines the bandwidth of the kernel. In spatstat the functions `bw.diggle()`, `bw.ppl()`, and `bw.scott()` can be used to estimate the bandwidth according to difference methods. The helpfiles recommend the use of the first two. These functions run algorithms that aim to select an appropriate bandwith.


```r
bw.diggle(jitter_bur)
```

```
##    sigma 
## 3.693017
```

```r
bw.ppl(jitter_bur)
```

```
##  sigma 
## 34.135
```

```r
bw.scott(jitter_bur)
```

```
##   sigma.x   sigma.y 
## 270.37651  93.98278
```

You can see the Diggle algorithm gives you the narrower bandwith. We can test how they work with our dataset using the following code:


```r
par(mfrow=c(2,2))
plot(density.ppp(jitter_bur, sigma = bw.diggle(jitter_bur),edge=T),
     main = paste("h = 0.000003"))

plot(density.ppp(jitter_bur, sigma = bw.ppl(jitter_bur),edge=T),
     main=paste("h =0.0005"))

plot(density.ppp(jitter_bur, sigma = bw.scott(jitter_bur)[2],edge=T),
     main=paste("h = 0.0008"))

plot(density.ppp(jitter_bur, sigma = bw.scott(jitter_bur)[1],edge=T),
     main=paste("h = 0.004"))
```

<img src="06-week6_files/figure-html/unnamed-chunk-19-1.png" width="672" />

Baddeley et (2016) suggest the use of the `bw.ppl()` algorithm because in their experience it tends to produce the more appropriate values when the pattern consists predominantly of tight clusters. But they also insist that if your purpose it to detect a single tight cluster in the midst of random noise then the `bw.diggle()` method seems to work best.

Apart from selecting the bandwidth we also need to specify the particular kernel we will use. In density estimation there are different types of kernel (as illustrated below):

![](img/kerneltypes.png)
Source: wikepedia

You can read more about kernel types in the Wikipedia [entry](https://en.wikipedia.org/wiki/Kernel_(statistics)). This relates to the type of kernel drawn around each point in the process of counting points around each point. The use of these functions will result in slightly different estimations. They relate to the way we weight points within the radius: *“The normal distribution weighs all points in the study area, though near points are weighted more highly than distant points.  The other four techniques use a circumscribed circle around the grid cell.    The uniform distribution weighs all points within the circle equally.  The quartic function weighs near points more than far points, but the fall off is gradual. The triangular function weighs near points more than far points within the circle, but the fall off is more rapid. Finally, the negative exponential weighs near points much more highly than far points within the circle and the decay is very rapid.”* (Levine, 2013: 10.10).

Which one to use? Levine (2013) produces the following guidance: *“The use of any of one of these depends on how much the user wants to weigh near points relative to far points.  Using a kernel function which has a big difference in the weights of near versus far points (e.g., the negative exponential or the triangular) tends to produce finer variations within the surface than functions which weight more evenly (e.g., the normal distribution, the quartic, or the uniform); these latter ones tend to smooth the distribution more*. However, Silverman (1986) has argued that it does not make that much difference as long as the kernel is symmetrical. Chainey (2013) suggest that in his experience most crime mappers prefer the quartic function, since it applies greater weight to crimes closer to the centre of the grid. The authors of the CrimeStat workbook (Smith and Bruce, 2008), on the other hand, suggest that the choice of the kernel should be based in our theoretical understanding of the data generating mechanisms. By this they mean that the processes behind spatial autocorrelation may be different according to various crime patterns and that this is something that we may want to take into account when selecting a particular function. They provide a table with some examples that may help you to understand what they mean:

![](img/kerneltips.png)
(Source: Smith and Bruce, 2008.)

The default kernel in `density.ppp()` is the `gaussian`. But there are other options. We can use the `epanechnikov`, `quartic` or `disc`. There are also further options for customisation. We can compare these kernels:


```r
par(mfrow=c(2,2))
plot(density.ppp(jitter_bur, sigma = bw.ppl(jitter_bur),edge=T),
     main=paste("Gaussian"))
plot(density.ppp(jitter_bur, kernel = "epanechnikov", sigma = bw.ppl(jitter_bur),edge=T),
     main=paste("Epanechnikov"))
plot(density.ppp(jitter_bur, kernel = "quartic", sigma = bw.ppl(jitter_bur),edge=T),
     main=paste("Quartic"))
plot(density.ppp(jitter_bur, kernel = "disc", sigma = bw.ppl(jitter_bur),edge=T),
     main=paste("Disc"))
```

<img src="06-week6_files/figure-html/unnamed-chunk-20-1.png" width="672" />

When reading these maps you need to understand you are only looking at counts of crime in a smooth surface. Nothing more, nothing less. Unlike with choropleth maps we are not normalising the data. We are simply showing the areas where there is more crime, but we are not adjusting for anything (like number of people in the area, or number of houses to burgle). So, it is important you keep this in the back of your mind. As [this comic](https://xkcd.com/1138/) suggests you may end up reading too much into it if you don’t remember this. There are ways to produce density maps adjusting for a second variable, such as population size, but we do not have the time to cover this. 


There are also general considerations to keep in mind. Hot spots of crime are a simply a convenient perceptual construct. As Ned Levine (2013: 7.1) highlights *“Hot spots do not exist in reality, but are areas where there is sufficient clustering of certain activities (in this case, crime) such that they get labeled such. There is not a border around these incidents, but a gradient where people draw an imaginary line to indicate the location at which the hot spot starts.”*  Equally, there is not a unique solution to the identification of hot spots. Different techniques and algorithms will give you different answers. As Levine (2013: 7.7) emphasises: *“It would be very naive to expect that a single technique can reveal the existence of hot spots in a jurisdiction that are unequivocally clear. In most cases, analysts are not sure why there are hot spots in the first place. Until that is solved, it would be unreasonable to expect a mathematical or statistical routine to solve that problem.”* So, as with most data analysis exercises one has to try different approaches and use professional judgement to select a particular representation that may work best for a particular use. Equally, we should not reify what we produce and, instead, take the maps as a starting point for trying to understand the underlying patterns that are being revealed. Critically you want to try several different methods. You will be more persuaded a location is a hot spot if several methods for hot spot analysis point to the same location.

## Adding some context

Often it is convenient to use a basemap to provide context. In order to do that we first need to turn the image object generated by the `spatstat` package into a raster object, a more generic format for raster image used in R. Remember rasters from the first week? Now we finally get to use them a bit!


```r
library(raster)
dmap1 <- density.ppp(jitter_bur, sigma = bw.ppl(jitter_bur),edge=T)
r1 <- raster(dmap1)
#remove very low density values
r1[r1 < 0.0001 ] <- NA
class(r1)
```

```
## [1] "RasterLayer"
## attr(,"package")
## [1] "raster"
```

Now that we have the raster we can add it to a basemap. 

Two-dimensional `RasterLayer` objects (from the `raster` package) can be turned into images and added to `Leaflet` maps using the `addRasterImage()` function.

The `addRasterImage()` function works by projecting the `RasterLayer` object to EPSG:3857 and encoding each cell to an RGBA color, to produce a PNG image. That image is then embedded in the map widget.

It’s important that the `RasterLayer` object is tagged with a proper coordinate reference system. Many raster files contain this information, but some do not. Here is how you’d tag a raster layer object “r1” which contains WGS84 data:


```r
library(leaflet)

#make sure we have right CRS, which in this case is British National Grid

epsg27700 <- "+proj=tmerc +lat_0=49 +lon_0=-2 +k=0.9996012717 +x_0=400000 +y_0=-100000 +ellps=airy +towgs84=446.448,-125.157,542.06,0.15,0.247,0.842,-20.489 +units=m +no_defs"

crs(r1) <- sp::CRS(epsg27700)
```

```
## Warning in showSRID(uprojargs, format = "PROJ", multiline = "NO", prefer_proj
## = prefer_proj): Discarded datum Unknown based on Airy 1830 ellipsoid in Proj4
## definition
```

```r
#we also create a colour palet
pal <- colorNumeric(c("#0C2C84", "#41B6C4", "#FFFFCC"), values(r1),
  na.color = "transparent")



#and then make map!
leaflet() %>% 
  addTiles() %>%
  addRasterImage(r1, colors = pal, opacity = 0.8) %>%
  addLegend(pal = pal, values = values(r1),
    title = "Burglary map")
```

```
## Warning in showSRID(uprojargs, format = "PROJ", multiline = "NO", prefer_proj =
## prefer_proj): Discarded ellps WGS 84 in Proj4 definition: +proj=merc +a=6378137
## +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null
## +wktext +no_defs +type=crs
```

```
## Warning in showSRID(uprojargs, format = "PROJ", multiline = "NO", prefer_proj =
## prefer_proj): Discarded datum World Geodetic System 1984 in Proj4 definition
```

```
## Warning in showSRID(uprojargs, format = "PROJ", multiline = "NO", prefer_proj =
## prefer_proj): Discarded ellps WGS 84 in Proj4 definition: +proj=merc +a=6378137
## +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null
## +wktext +no_defs +type=crs
```

```
## Warning in showSRID(uprojargs, format = "PROJ", multiline = "NO", prefer_proj =
## prefer_proj): Discarded datum World Geodetic System 1984 in Proj4 definition
```

```{=html}
<div id="htmlwidget-5b9b230cdf2dd56e40a9" style="width:672px;height:480px;" class="leaflet html-widget"></div>
<script type="application/json" data-for="htmlwidget-5b9b230cdf2dd56e40a9">{"x":{"options":{"crs":{"crsClass":"L.CRS.EPSG3857","code":null,"proj4def":null,"projectedBounds":null,"options":{}}},"calls":[{"method":"addTiles","args":["//{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",null,null,{"minZoom":0,"maxZoom":18,"tileSize":256,"subdomains":"abc","errorTileUrl":"","tms":false,"noWrap":false,"zoomOffset":0,"zoomReverse":false,"opacity":1,"zIndex":1,"detectRetina":false,"attribution":"&copy; <a href=\"http://openstreetmap.org\">OpenStreetMap<\/a> contributors, <a href=\"http://creativecommons.org/licenses/by-sa/2.0/\">CC-BY-SA<\/a>"}]},{"method":"addRasterImage","args":["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAbvUlEQVR4nO19XW9c21blWF97V5W/k5wD4l5xW3wIuqXYzgnngkBNP6Huh27REr+AB57gDXHvif3scq4aeEB0P/ZLI/ED+ANIIIGAe5I4avoRQd8+cA5JHDu2q/ZeH7Mf5lq7dpW37fqwE1dc46iSnNiuVNWee665xhxzLEFEWODuQn7oF7DAh8UiAO44FgFwx7EIgDuORQDccSwC4I5jEQB3HIsAuONYBMAdxyIA7jj0h34Bk2B1c486LQNtJEIghECQUkApiRACnA2wLuDNsyfiQ7/WecHcZYAQCMHXHoEQQkAIAAEQAljb7C4aHGNirjKAkhLWBRCIL3ggSBKgEG94AgQEIBbXf1zMVQY4fP5EBCJYGxACwRNnAOsCvCcQESCARf4fH3OVAQDg6MXOueu7vtUlElwPCLGIgEkwVxngIrx9sSNCAC8LRFwMLDAW5i4DXIYQ+Mq/bcgSCzRDfEyKoJWHe/Tu5e7i4k+AjyoAFpgcH0UNsMD0WATAHcdcFoErD/dIKwHvCceLNX8mzF0ArG91SSvm/xf7vdkxd0uAMRJGK2SZgjESq5t71xYFn37+g6HnWnl4fc99WzF3GcDagE6HO4IAIMvrWQH+7a//D5JScEARuMsoP/7VZa4ywPpWl4QApBJQRkFrCaVmv0if/86fkNQSSklIISAlP7SS+PQXfvBRZ4G5CoDE9UspIJWA1BJyxrv089/+XwQAIj1nvPgq/f9IgD14/JTWtgbt5nlfJuZuCQAAITgQRLxY0+Ln/8t/p6UfX4LQMj4vBxlRDAgx/Pzf/pXfJ60lKBDWtrokgLlfJuYqA6SiP5GXQnAwTIOf/U9/RK70cD0HX3gEH2rPGb+p9ufv/Ic/JKkELztacoaIj3pGmDfMVQAEcM+fO34UBSDT4ZuvTmD7DvbMwp1ZeBtAHAPDzykEfvJX/4AAQEoJqWKtUF+OpgzC24C5WgIoyr7qcrBpbz0CoSwczKmFsgGucAiBICBAIM4y8UEUM0EsQPni8/PwsnEtb++DYK5e+tHBjiAQvA/wLlRBMA0yo1AWHsWpRXlawvY9QgiDbyACxQggIlCo6QxqN7wQnAGuk494n5irAACAVqbhfYBzAd55BD/d5/7qh1+IQIR+36I4c7Clq4Ip3fzp7qdA8FF8SoGDoV6H8K5h7j5KAHMYANbxxXelh7UBzoerf+gCHD7fERSAfuFgS84o1aISb3iK8vPgOOu4euYhQAqmpa+Dj/gQmLsAOHz+RIQAlDbAWj+z+ufVl18IoigsDbXCMgmNCfCe4FzggLOegyBwsCT+YBEA7xFHBzsiEOHw+fVIvw6f7wiiWlFZ2/4F4oLTeQ4AG4dPEhIzOa91wFwGANCsDp4FQgiEePcryVs9IVhk6kOIaz6v/UcHOyIRRrUn4JmEG8Dqwz26qWGXudoG3iTS2i+lgDYSQgjebXgPHwjHB8O6gySlqygJqtUP14jVzT1C3GquPtyj69Y/LAKgBgEBpSVMriEkgAIQpT938QEg7T59LEKDPx8k1/nKcEMTT3O7BFyFSZs0iffXRiFra2RtA20UxAVcf2IkU4E4y27kMnBQ0Y3NO3yUAbCx3aXMSGxs74/9kTGvD+hMQrc1PzJ5Ic2bUn9VHLqbCQCAg4AINyJ/++gC4MHjp2S0Qp5rGC2xOmYmqHQAWkLlCipXkFriIppfRgaQySPCTc8jHB3czLDLR1cDeB+Qdwx0piCEGPvOHHD73GYWst4WHMb6VpeMlghEePNsvqeQ5joDjG6N7j3ap7SO60xBG2boVh7u0ermHq1f0rYlDGhfcoTgCOQDwsjgzP1H+2S05OeWYu4FIXMbAKsP90gIDKX4qkWrBKSSVedOSQGjJIyRuPeouS5IlK+3Hq7v4PoWrvTwI70G5wlKS2jNreE57gQDmOMAQBKDCFQM3KsffiFqXwYgqmaN1hJaK2jV/JZdiGxf4VGeWdhTC9tn2jdhfatLbEmT5GO4MfLnfWF+A4CqX4b/OlK33gfu3hGqrKA0/95E2R692BEgoCgcilOL/qlFUbihXkPaKYgkDvgIMLcBcPxyV8QCfIiA8Z7gLHcLfXQSAajq24tLKFulJIrSo9+z6PcsytIPfT39PNcLBAo4VyPMG+Y2AAC+a0f3xm9f7AhbetjCw5acwmsKMlymIzt8zu5iKbmMdhqTXpACIfgAH8KNb/9uGh/dNhAASuvhQ6gEHt5HJzE/0sBpwGV0bukCcqNYIEIE5+b77gfmPANchLcvdkS669++2BFHBzvCuVQX0FSr98Z2lxIr7ANf/JQx5hkfZQYAcM4s0vlQFXBKyYndRLwnKCVjD2DQBJp3fJQZoAlHMSsoJZBlErlRY//sysM9qiuEgqePxofozgQAwAWcyRRaHYNWW2N9+2qRxdomTwDx1i+SRVMqkW8j5noJWHm4RybOB3ofrpSIaSW5zdvSkOr8Nq8JBKrmAHgnQTfWmPkQuLUBkFg358NQZZ7cQQCBTEuYTEEpCef8leu6NgrZkoFZMpBSoH9mL30NiTBK8i9KffmPCLd2CVBxDk8riY1aqtaKDSKM4YuftzTyjq7avxc1fNa3uqQzCbNkYFZy6OgxcHUzpxZP13Dt17e6dJvEo7c4AGTk7+UQf586cSkATIvVO6alq+9vfD7JngIq11AtDZUpbhhd0s0ZqHEGGkApxFi1QxPuPdonIYBMq6Gg/pC4lQGwujlouigpUMaGzNpml5jTZ9Wu0pLbvvGCKiUubPaoONUrtGS9X7IUvsJe/vhgV4S49YPgzGRGstK40IqDWRt54et837gdr2IEXHXXxBkAj2BHKjYJNqQUEIofqRV8kYZPx4sP4imfkPoEY0jtjl7sVB7UVWaa4gIWpa9+ftR44kPhVgYAVWkXw0VXNbE7GBMfzOrRhTTv+laXtOEPnQLB9xx83/FIOAjH41T1ojYHGDPQuHIzYFBQCjkwn5i1FriOWYFbGQDHB7sihEjdelbbH73gaSAfCN6xGte7AG8DfOHhy1ANb45CK14qpJYgF+DOLPf8rUcrH3MjFDNFMoVIYpNJ3tPoc82Ce9v7JCVmriVuZQAAqCaAnQ8wsbB793JX8N97ntErA5s89Cxs4XhiuIGiVVpwABgJ8gR35mIA8HwhwHfTZXdk8gtItQAwuTtJnqlKq0ANwybj4t72PkklkGUaRqsLdz7j4NYGwOsvn4gkt66rcpyjakavtB5l36E4cygLx19rEIEqJdlQSkkET7B9h7LPAXP4fEesbu5Rmu5evSCtpnlEXnKANK0zCZzngPYTzBGsbu5RXd6eCuFWSyNvKZhstsnkWxsAAPfnU0cv/d3RwaDTR0Qo+o5n/AsPQjNHz4ogCQiAfIAvPaz10KoSjlVCkcs+ykyr2GYOVUE4yTr+5tkT4f3giJursLbZJeY9JO5/tk/3P2PRa55r5B1TDa/M4k1wa5nAhCZmb7QNu7q5R1rKS1NqpeBxgxHvRB1XljAYzAg2wYcAQTwLkKr5zI/fVAI4mMfpRD54/JS0FlhayWEyBReVSkII5G2NbMmwOokIsu8meg113OoMMIr1rW7jlOzxwa54c0lvnohAnhCcR7CcgjsdM/TzIcq7UhA1/TuHz3cEH07FvEKWa2S5mrgaH6cN7VxAZynDyicdrHxrBcufdNBZzpDlCqZjkK1kMMs8/zCLVd61BsAk26JJ8eDxU8pzhewSafdFCIF3DKGMu4a4i6jj6GBHpAuT2r9N76fT0Zz+jYRpaZhcQevr3dPf/2yflBJYWm9h5d+sYfnn72H5O2tor7eY9WxrmOUMZimDyvVMATDxErCx3aWlpQwm1wg+oCwcH9kWT/FkvT53z66rZ76x3aVOnPbxNuDsiibOKCqLF+vZVygMLOGakMa+PAirm3tUX1pS5a8MM5BEBK0nez1XIcs0hADan3TQ+nf3sfytJZz83xO4dyUonDKVvWQAAvSRmolUmiIDpH9sZLWMJImI0mkpxUzbkzq0lsjbBq3lDHnHwGiJB589PffcF6XiEEWcwQZmAcPV7mJ1m5g6vvqr3xMQ4BlCw49Z7WpHkeUKJldofdrBz/30Mn7j2xo/9dMryD/tDGjvtobqaKj84gnmcTBxAJz7t2qfo4hfr4YnhLiWpocxCqatkS1nMG3No19m+KWvPuStXFPapkQe1QyeLpNzU/xvVHJeRyUSiVLx64RKo20P2vjufYVf/HGJ795X0PdanPKNhGxpyLaGzBWknN42f/IAiCyYSGaJAhUNy69ADDluX4eLplISOo8j27lmYme065du2dqkUAL7/HDx58fIAKkovGgcm+LzBR94fvCaFUKp4SWXDb69JPCdVYlvLQnIZQNpJISREJmCyDVPMMvp7WkmqgHWNrvUymMbVcmKdk0DEhRpssR1B0kAzR4AQiI2fST/LsR5EiaJ+Rvm6H0sApPtSwhXj1tf9nXvCK4MENLDldN7FV6NONoWHxCx8aU5CCAEoAaupdNgogyQjmpPVu1Ccl+14uhjQKSOXcoCs6Ka2vXDJo11HL+8+K49PtgVzg/2/7NW7c4F2MKh7FkeQBlhH+892qdZlr7gAk8nn1r88xnhR+8I/3JGoL7jIDCKM4AUAzPLKbsLYwfAysM9Gnjox7QTfzqEulSKBhO6QqAYQ3d3FYLnho/rs7O3vyDtXnbXOjeglV9/OZue3/qAou9QnFkUfTdE6yYtQ6tl8GPfne6wCe5zeNjXPfzwdcDffu3x7E2APyq5zspVzACIN0WYurs0dgCkdX2o4kytWfBdxgXTwEW76uXP2La0NvDddlKi7NnqTp4EycsnXIOc/93LXWGtRxkp5cQfbGzvkxRAq6XRWjJotQ0+eXx+t3IVysKjLByKb87w8h9O8Wc/8vjf/3gG+7YPKAHVMRC5il4GfDNMax8zfg2QBmJTQ8QPiqlhjT3FNUkMZummeWU1WOtR9BwbNlqPsgwTN2KOX+6K1Zq+f1Y0KZAPnz8Rnzx+SllbI+tk8JbnEydFWXpIIdD71zPkf/8a/+9VD+6wD3dcQnU05IoBcsXiFusRZvAnGv9jjM2XxKq5MhIrno0Uq2+rRBwDUcesOHy+I4q+Q//Uot9zAGi6NC7Ga+E+ePyU7j/an8qcUWtmCLMlZux0NjlV/ObZE2FdwOlhHyf/cIST//MaZ/90DNdzUC0NuZpBtBTgCb5kZnNajB0ARwc7IiRLtNLDFg629LA+wNWq4BCDpPLzH1X1TIlXP/xC9AsHUPPddxU2trukpLwyHW1s79PgOBrgk8dPaRIRaDrQSuWq0ilOU6UfHeyIom/x7ptTvPvRO/Re9UA+QC4ZiLUcyBRb2ZR+Jou6iRKpDzx7X5a8RpVlABEN2bYeH+yKtN56nyRX1zNC/fbFjnj15RcTP1dqq2rNPMFFDOXaVpdaLYV2R6PdMWi3eX5ATaIETuLBmtHUtNu0r//m+6J/anF62EdxynSzWjJYbkloAZD18KWfaU5xogB4+2JHBOI1qig8Fx8NF9f7wCYNLtwK9auKxIpWbOx0kYAiNwqttkFrJUd7JUN7OT46BlIIPBinoEudx0g7kyfMwhP9y998TxSlg7WeNQuZQlsKOE8IfdfoYzQJJm4GpV782maX3r5oXodZZcPj1LdhhFrWLnoTL3Hv0T6BgPaSQbZkkC1nAOJ+3BNczyIEGqsJFQLBlx6uZ/l352deAo1RzDrG9asXCHTm4E8dfOlncimZWhByFZM2ltL2PaHS/aRdSe3zWttkzz+dSW7CtA3McgYhRaU4tkbClR69nsXG9j5dFtQUAFd6QPDvtgzjC08vQPC8syLHd/3JiQMd9uFOSjjb7GU8Lm69Iug6wHRFs9Q8zxSyXMUhE+6uqZaG0GLQ7FEC5UnJy9klH/XGdpfyXMNZpoetZZ5g1gzgA9PYrnDwRwXk12fwr/sojwvYYjai7cMv0O8B1a7ERzl5XDPvPdqnvM2kTdYxUJmMhRsgtIRsa6gVA71kuAmlLm/9ZvE4WwrgIrnvYN3w1HK9UbW+1aVxxC0unVjScyhf9WC/OkHx9SmKdyVKuwiAKxFC/AAdewcloYrRkp3BY5tZalYNkw0gR3z3awlpFDeh5MU8woPHTymLCiEhuRC27ryJlBSsk2DNH+sKrwqCNBNRnln0X/fQ/+oE/W/OUJyUM9PaUy8BqTdwm50yNra7RMTchPPsFlZfL3WSdS0Z1gz0Pe+rzywUEWQmASMHR8alRwOyTCHvGCgtUfYcQA55NiwYvbe9T5lR7DkgBExcelzpsb7Vpcs+y1am0e87mMM+XM/B9t2V4+3jYOoMoNV40fuhwKmWP08tZWUWVf8eKSWTNbmG1ApEBNd3KE9KuBMLf2rhew6hYLo1ULOQ5N6jfcpyhaxjeOw8kyNn0DKUFnGyWSFrabSWMrRXcrSWsnPBMopv/u77wrmAs3cFTg/7OHtX4Ou//f7MN9/0AaAFTJxyHWt/fEO4d8GZAMkbWGsJ19ABWt3cIyGjxiCu68HxpFF5UqI8KWFPLfxJyUfLlp5PLm3Y1CslYiAp6JrNfP36rz7co2qi2UiYXCFfzpCv5bwE5Tzhs7HdpQefPaX7n51/X2+ePRFlyTrMf/7r711L5p1qCVjd3KN2i4siUEDRn73lOw2YtgXWt7v0doQeTrp97wOEFefEnRVSY8uxs2hZ09irXEEAcIWDsyGeCzRA4vjbbc0iGT0QrAiMrBZiMFwqJI+qmSUuMIl4r59UTlpJEAj3P9un0TX+9SVM6OomL8ujZxzde7RPRM2czFQZoJqkqbV837frRfLsN1pCQAwtRaube+wjUB3y3GzqTDRwB/d9zxe6jHOHlieIfMEP8gEQXFDef7RPycJG64HoJYlWkuZwNFvUt6BCSshMDcwqYkHItYRmI6uWxiePn9L9BgHsKFKvg9lOWfv7fVLRMb3plPOZeIDLRrLXNrukFEfjdR/xBkTHj7hXVyNUaKWQu6T7d3ywK771y79PvvCAEHB9bm6xn6CoRs9Z98d3PvsEBgjBBWQKKiEEyDMDCCDy8zSUAo4PdsWnn/+AmNSptUljm11EtZXJFLKOBiCglIOQAs4G3H+0T9aFS3SKQJ7xEiNdwMZ2l3wgmGiMAUKju9lUAUCod/xCJQipf0+WpRTcnMpmRZKcsQZxmN2r/AXCoCPZxFx6z9Iu77nD6cqau3g6MSQ+r1QiGlKlTqEEQFUr1lkPecatahtPIh81q/QuwAk2nOJBFc4uwfpqrkJHNlJIAalZeueth9ISdEHVnw7KMPGQDBfNtYgGNHj68yimWgKOD3ZFiPP5zlE1vp2wsb1PWaaRtw3yGWnQsTCyPTs+2BU+hMpfwJjmt+lcQNn3KHsOZZ+7agKI5wEMikMIxOPkFLKW4Udbw0SFMhCFKmcWxSnLxJq8inwYsIOucLCnFu5dCXfm4F2ojqdPbKRpG+QrGdprLbSXM+S5ajS1co5H6HWmWD2dcT2RXFOSdL0pGU69CwgUtQEj49tA3CHkfPxaMm9qGuSYBUmcEkLz9sx7qg6Xrh8kUYfzsbXdd0zfEg0k2XpwcijAgyA61zAtBdPiD5qHQiRCINiazbxzAd80bNHevtgRLgZBWXgUJyWKowLFSQlXchZA0iJoCdXSyFYy5BsttNZy5G0DNXIXr2/xuLg2KQDUIABSBkuK7YYrMH0ABIKLp22PEhhKDcybdK6iodP1lgHsEELRCfy8zv/NsyfCuXAuDdfx9vmOcC6gtCxqEeBj4FXy8CFUSmQhBU8CZVHoYSREbHWHMPAssPZy0enRix3hPKEoHPqnJfrvChSnbFrp45wBeU5p0kiYlRz5vRby9Raytm7MLEZJKK0GGSBX0IaHRgnxM/LNsxBTBcDaVjcZZjR2oipVsB6c23Pd41M+HvHio9CziUUbh6U8fP5E8NnABCFRDb0A3IVL00RArDuUHBSWSSIX+wuvv/xCXBZwCe9e7grnCP2eQ++Es0bliBJ3H8EFCCWglgz0RgtmLefBmJq+YuXhHlWeRSk483jjZTwzmIytnQ9omqCeOABWHu5RGp68WJg5KMIqW5VrPmLl3cuo9b+GqZzjg13BAxjp4seq3nr4Ivbc/eA9pd1BiKon78PEqp+jgx1hHVvU2ChVT/MGtmfhCw8QIFsKajWDWjbQma4GQVc3+TokgYvSEtLIQQBEmhlAdfp5Eyau0NIpXFxpN7/rNI0bLAtHQ3X69vRY2+zSqLzs+OD6lL6iNuNHaZw8vo/qe+IvKRBsEfmCKf1+RrfHh893xI99/gMqew5SS2SeeAikrSHzWosa6fiagWmVSJZ5MfWrWAdYIWCJMEqUAbF+mPRFp/kAFYufJnjHH47tOf6QXEAxQ9962MNnuApO/zPL7EG6myAGFz8JX8sofnXpGJq+j8ZU8b1ZDz2DRcsoku9RcLws8bZE1KZy0/RVIhBQcc4CtQLSqGhn11z9r291KTNq8iWAx75QtUab2CUbfQOKnuWeuA3XIA1rHoBMqXsWcOrnz5Jl76zntwUPfyQRrO3zg7eNDmXp4Dw1rq3T4vD5jigLjzdfn+LZ//xN8ZdP/mu8ynE0riHMK9IqUHWseRUIWp7bOdx7tE9aSWStKQIg3XJ8ClfDuDg4tZUlD3OMHr02PahRYVyRNpg+CyRXUgKikoe3hzbyHM4NlNBFzApFya5kN2Ed/+rLL0R96/rnv/lr4i++9+sCFP0JkFjY6Hvkk/9BJJXissUSdXnOzMoYbkhlLT15AFS+uYRLqdY3z56IfulmFiwAya/3gh0HBp3XaRNBat4wXTrgNt48eyKODnbE27h1S7OF1ocPcmbQwZ/+VvXvJZ2DD7xL8al30fexaA28ddWyoswTisKz3W2mJy8C0+DHKP3ahOuaBwDOF0xDoKHfpkagwZZu9M6+iX7GLDg62BGrD/cGghcb4Poe0lhIrXgbGe3xpJRVpl7f6lJVPGoxeQAcH+yK1Hm7DYcnJIJrlhHpSiwaD4SYlxNB6o2hn/il/0YhBLieg9SDnYuUw1K2NLeZsvdURH1qsPhAH/zs3EAEETgYp52QBQZm09OMnd0GfPXXXBv8zH/8IxKiEkOdMztiDw9+ryEQxLR38dpml2b70K8PF4o97jh+7j//MVEg9E9KvDsucPh8R6RCeXnZoLOaTx8AC8wPfvLf/wH901/8bnWDrG7uUadt0F4y53cB1+FBv8DtQv3iAzwM41yALf1wAKxtdknI9y/vWuD94l//7guROIShJWAt+tuE0Ey61DHp0asL3E4MZQCKv46znbpIZLjAfGEoAI4PdkSS0F92969uRj9gXGy2sMB84BwPMA4JkvoAH8f52Xcb0/cxRwiGBeYT0wVApfK5eC5ggfnAVAFQP7fnNk8HL3A1phbtB7qZiZ8F3i8WVPAdx51wCFngYiwC4I5jEQB3HIsAuONYBMAdxyIA7jgWAXDHsQiAO47/DxtfFY8j+US1AAAAAElFTkSuQmCC",[[53.4512140379333,-2.2567461389902],[53.4387900210554,-2.21273638149381]],0.8,null,null,null]},{"method":"addLegend","args":[{"colors":["#0C2C84 , #2A5297 14.5029922166207%, #3B84AE 32.6346750166925%, #46B7C4 50.7663578167644%, #98D1C8 68.8980406168362%, #D6ECCA 87.0297234169081%, #FFFFCC "],"labels":["0.000","0.001","0.002","0.002","0.002"],"na_color":null,"na_label":"NA","opacity":0.5,"position":"topright","type":"numeric","title":"Burglary map","extra":{"p_1":0.145029922166207,"p_n":0.870297234169081},"layerId":null,"className":"info legend","group":null}]}],"limits":{"lat":[53.4387900210554,53.4512140379333],"lng":[-2.2567461389902,-2.21273638149381]}},"evals":[],"jsHooks":[]}</script>
```

And there you have it. Perhaps those familiar with Fallowfield have some guesses as to what may be going on there?

### Homework 1
*Ok, so see if you can do something like what we have done today, but for violent crime in the city centre. Produce the density estimates and then plot the density plot. In addition add a layer of points with the licenced premises we looked at last week.*

### Homework 2
*Produce a kernel density estimate for burglary across the whole of the city. Where is burglary more concentrated?*

## Spatial point patterns along networks

Have a look at this maps.  Can we say that the spatial point process is random here? Can you identify the areas where we have hotspots of crime? Think about these questions for a little while.

![](img/nonrandompoints.png)
(Source: Okabe and Sugihara, 2012)

Ok, so most likely you concluded that the process wasn't random, which it isn't in truth. It is also likely that you identified a number of potential hotspots?

Now, look at the two maps below:

![](img/randompoints.png)
(Source: Okabe and Sugihara, 2012)

We are representing the same spatial point pattern process in each of them. But we do have additional information in map B. We now know the street layout. The structure we observed in the map is accounted by the street layout. So what look like a non random spatial point process when we considered the full two dimensional space, now looks less random when we realise that the points can only appear alongside the linear network. 

This problem is common in criminal justice applications. Crime is geocoded alongside a linear street network. Even if in physical space crime can take place along a spatial continuum, once crime is geocoded it will only be possible alongside the street network used for the geocoding process. 

For exploring this kind of spatial point pattern processes along networks we need special techniques. Some researchers have developed special applications, such as [SANET](http://sanet.csis.u-tokyo.ac.jp/sub_en/manual.html). The `spatstat` package also provides some functionality for this kind of data structures.

In `spatstat` a point pattern on a linear network is represented by an object of class `lpp`. The functions `lpp()` and `as.lpp()` convert raw data into an object of class `lpp` (but they require a specification of the underlying network of lines, which is represented by an object of class `linnet`). For simplicity and illustration purposes we will use the `chicago` dataset that is distributed as part of the `spatstat` package. The `chicago` data is of class `lpp` and contains information on crime in an area of Chicago. 


```r
data("chicago")
plot(chicago)
```

<img src="06-week6_files/figure-html/unnamed-chunk-23-1.png" width="672" />

```r
summary(chicago)
```

```
## Multitype point pattern on linear network
## 116 points
## Linear network with 338 vertices and 503 lines
## Total length 31150.21 feet
## Average intensity 0.003723891 points per foot
## Types of points:
##          frequency proportion    intensity
## assault         21 0.18103450 0.0006741528
## burglary         5 0.04310345 0.0001605126
## cartheft         7 0.06034483 0.0002247176
## damage          35 0.30172410 0.0011235880
## robbery          4 0.03448276 0.0001284100
## theft           38 0.32758620 0.0012198950
## trespass         6 0.05172414 0.0001926151
## Enclosing window: rectangle = [0.3894, 1281.9863] x [153.1035, 1276.5602] feet
```

An `lpp` object contains the linear network information, the spatial coordinates of the data points, and any number of columns of *marks* (in this case the mark is telling us the type of crime we are dealing with). It also contains the local coordinates `seg` and `tp` for the data points. The local coordinate `seg` is an integer identifying the particular street segment the data point is located in. A segment is each of the sections of a street between two vertices (marking the intersection with another segment). The local coordinate `tp` is a real number between 0 and 1 indicating the position of the point within the segement: `tp=0` corresponds to the first endpoint and `tp=1` correspond to the second endpoint.

The visual inspection of the map suggest that the intensity of crime along the network is not spatially uniform. Crime seems to be concentrated in particular segments. Like we did before we can estimate the density of data points along the networks using Kernel estimation (with the `density.lpp()` function), only now we only look at the street segments (rather than areas of the space that are outside the segments). The authors of the package are planning to introduce methods for automatic bandwidth selection but for now this is not possible, so we have to select a bandwidth. We could for example select 60 feet.


```r
d60 <- density.lpp(unmark(chicago), 60)
```

We use `unmark()` to ignore the fact the data points are marked (that is they provide marks with informtation, in this case about the crime type). By using `unmark()` in this example we will run density estimation for all crimes (rather than by type of crime). We can see the results below:
 

```r
plot(d60)
```

<img src="06-week6_files/figure-html/unnamed-chunk-25-1.png" width="672" />
 
If rather than colour you want to use the thickness of the street segment to identify hotpspots you would need to modify the code as shown below:
 

```r
plot(d60, style="width", adjust=2.5)
```

<img src="06-week6_files/figure-html/unnamed-chunk-26-1.png" width="672" />



This is very important for crime research, as offending will be constrained by all sorts of networks. Traditionally, hotspot analysis has been directed at crimes that are assumed to be situated across an infinite homogeneous environment (e.g., theft of motor vehicle), we must develop an increased awareness of perceptible geographical restrictions. There has been increasing recognition in recent years that the spatial existence of many phenomena is constrained by networks. 

These networks may be roads or rail networks, but there may be many more: 

> Environmental crimes could exist along waterways such as streams, canals, and rivers; and thefts of metal could occur along utility networks such as pipelines. Those
sociologically inclined might be able to offer more examples in the way of interpersonal networks. 

- [Tompson, Lisa, Henry Partridge, and Naomi Shepherd. "Hot routes: Developing a new technique for the spatial analysis of crime." Crime Mapping: A Journal of Research and Practice 1, no. 1 (2009): 77-96.](http://discovery.ucl.ac.uk/20057/)


While sometimes there may be issues with linking points to routes due to problems such as bad geocoding, as we had discusses in great detail in week 4, there are obivious advantages to considering crime as distributed along networks, rather than continuous space. 

