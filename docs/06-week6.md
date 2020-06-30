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
## CRS:            27700
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
## 26.99239
```

```r
bw.scott(jitter_bur)
```

```
##   sigma.x   sigma.y 
## 270.27568  93.95574
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

<!--html_preserve--><div id="htmlwidget-ca1efc30e3be26aa67d4" style="width:672px;height:480px;" class="leaflet html-widget"></div>
<script type="application/json" data-for="htmlwidget-ca1efc30e3be26aa67d4">{"x":{"options":{"crs":{"crsClass":"L.CRS.EPSG3857","code":null,"proj4def":null,"projectedBounds":null,"options":{}}},"calls":[{"method":"addTiles","args":["//{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",null,null,{"minZoom":0,"maxZoom":18,"tileSize":256,"subdomains":"abc","errorTileUrl":"","tms":false,"noWrap":false,"zoomOffset":0,"zoomReverse":false,"opacity":1,"zIndex":1,"detectRetina":false,"attribution":"&copy; <a href=\"http://openstreetmap.org\">OpenStreetMap<\/a> contributors, <a href=\"http://creativecommons.org/licenses/by-sa/2.0/\">CC-BY-SA<\/a>"}]},{"method":"addRasterImage","args":["data:image/png;base64,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",[[53.4514660585405,-2.25818225128802],[53.4390428773239,-2.21417729398327]],0.8,null,null,null]},{"method":"addLegend","args":[{"colors":["#0C2C84 , #214390 8.94679022686499%, #30619E 20.1305093591137%, #3A80AC 31.3142284913623%, #40A0BB 42.497947623611%, #57BBC5 53.6816667558597%, #89CBC7 64.8653858881083%, #B1DCC9 76.049105020357%, #D7ECCA 87.2328241526057%, #FAFDCC 98.4165432848544%, #FFFFCC "],"labels":["0.000","0.001","0.002","0.002","0.002","0.003","0.004","0.004","0.005"],"na_color":null,"na_label":"NA","opacity":0.5,"position":"topright","type":"numeric","title":"Burglary map","extra":{"p_1":0.0894679022686499,"p_n":0.984165432848544},"layerId":null,"className":"info legend","group":null}]}],"limits":{"lat":[53.4390428773239,53.4514660585405],"lng":[-2.25818225128802,-2.21417729398327]}},"evals":[],"jsHooks":[]}</script><!--/html_preserve-->

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

