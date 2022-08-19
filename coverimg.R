# making cover image, but need to get week 2 stuff into environment

police_distances$distance_m <- round(police_distances$distance_km*1000, 0)

# Bin ranges for a nicer color scale
bins <- round(quantile(police_distances$distance_m),0)
# Create a binned color palette
pal <- colorBin(c("#0868AC", "#43A2CA", "#7BCCC4", "#BAE4BC", "#F0F9E8"),
                domain = police_distances$distance_m,
                bins = bins, reverse = TRUE)

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

mapview::mapshot(m, file = "coverimg1.png")
