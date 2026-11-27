# Country outlines for map context

`south_america.geojson`: the countries of South America from Natural Earth
1:50m Admin 0 Countries (version 5, via rnaturalearthdata 1.0.0), simplified
to about 2.5 km and kept with only `iso_a3` and `name`. `fa_map()` uses it to
draw the neighbouring countries and the locator inset.

Natural Earth is in the public domain: <https://www.naturalearthdata.com/about/terms-of-use/>.
The department and district boundaries are not here; they come from INEI's
geoserver through `fa_geometry()`, into the cache.
