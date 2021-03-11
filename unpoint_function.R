st_un_multipoint = function(x) {
  g = st_geometry(x)
  i = rep(seq_len(nrow(x)), sapply(g, nrow))
  x = x[i,]
  st_geometry(x) = st_sfc(do.call(c,
                                  lapply(g, function(geom) lapply(1:nrow(geom), function(i) st_point(geom[i,])))))
  x$original_geom_id = i
  x
}

police <- st_un_multipoint(comisarias)
