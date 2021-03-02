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
##    sigma 
## 41.98559
```

```r
bw.scott(jitter_bur)
```

```
##  sigma.x  sigma.y 
## 270.3468  93.8943
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
<div id="htmlwidget-b2d5c24784cd4aa3a3eb" style="width:672px;height:480px;" class="leaflet html-widget"></div>
<script type="application/json" data-for="htmlwidget-b2d5c24784cd4aa3a3eb">{"x":{"options":{"crs":{"crsClass":"L.CRS.EPSG3857","code":null,"proj4def":null,"projectedBounds":null,"options":{}}},"calls":[{"method":"addTiles","args":["//{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",null,null,{"minZoom":0,"maxZoom":18,"tileSize":256,"subdomains":"abc","errorTileUrl":"","tms":false,"noWrap":false,"zoomOffset":0,"zoomReverse":false,"opacity":1,"zIndex":1,"detectRetina":false,"attribution":"&copy; <a href=\"http://openstreetmap.org\">OpenStreetMap<\/a> contributors, <a href=\"http://creativecommons.org/licenses/by-sa/2.0/\">CC-BY-SA<\/a>"}]},{"method":"addRasterImage","args":["data:image/png;base64,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",[[53.4512140379333,-2.2567461389902],[53.4387900210554,-2.21273638149381]],0.8,null,null,null]},{"method":"addLegend","args":[{"colors":["#0C2C84 , #1B3A8B 5.52122518514406%, #2C5899 16.5769587717622%, #3776A8 27.6326923583804%, #3E95B6 38.6884259449986%, #41B5C4 49.7441595316167%, #79C6C6 60.7998931182349%, #A3D6C8 71.8556267048531%, #C8E6CA 82.9113602914713%, #ECF6CB 93.9670938780894%, #FFFFCC "],"labels":["0.000","0.000","0.001","0.001","0.001","0.001","0.001","0.002","0.002"],"na_color":null,"na_label":"NA","opacity":0.5,"position":"topright","type":"numeric","title":"Burglary map","extra":{"p_1":0.0552122518514406,"p_n":0.939670938780894},"layerId":null,"className":"info legend","group":null}]}],"limits":{"lat":[53.4387900210554,53.4512140379333],"lng":[-2.2567461389902,-2.21273638149381]}},"evals":[],"jsHooks":[]}</script>
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

