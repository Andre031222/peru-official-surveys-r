utils::globalVariables(c("fa_fill", "fa_class", "fa_label", "fa_x", "fa_y", "fa_ref"))

#' Choropleth map of estimates
#'
#' Draws estimates by department or district on the INEI boundaries
#' ([fa_geometry()]), ready for a paper: UTM zone 18S projection, a legend
#' by classes, department names, a north arrow, a scale bar in kilometres
#' and, around Peru, the Pacific Ocean, the neighbouring countries and a
#' locator inset of South America. Areas without an estimate are grey;
#' estimates that are only a reference (INEI "referencial": CV above 15% or
#' few cases) get an asterisk and a dashed outline.
#'
#' @param x A table with one row per area, e.g. from [fa_estimate()],
#'   [fa_indicator()] or [fa_link()].
#' @param value Column to map.
#' @param level `"department"` or `"district"`.
#' @param key Column with the area code. By default `department`,
#'   `ubigeo_base`, `ubigeo` or `domain`, the first one found.
#' @param base With `level = "district"`, the census year of the codes in
#'   `x` (e.g. 2017 after [fa_link()]). The district boundaries are then
#'   merged into the districts of that year; districts that split from
#'   several of them stay grey.
#' @param percent Show the values in percent.
#' @param title Map title.
#' @param geometry Boundaries to use instead of downloading them, an `sf`
#'   object with `code` and `name` as returned by [fa_geometry()].
#' @param cache Cache folder for the boundaries.
#' @param breaks How to group the values into classes: `"quantile"` (each
#'   class with about the same number of areas), `"pretty"` (round
#'   limits), a numeric vector of limits, or `"continuous"` for a colour
#'   gradient without classes.
#' @param n Number of classes.
#' @param palette A sequential palette from [grDevices::hcl.colors()], such
#'   as `"YlOrRd"`, `"Teal"`, `"Purples"` or `"Viridis"`, light for low
#'   values and dark for high ones.
#' @param labels `"name"` (department names), `"code"` (INEI codes) or
#'   `"none"`. Districts are never labelled.
#' @param context Draw the ocean, the neighbouring countries, the locator
#'   inset, the north arrow and the scale bar.
#' @param legend Legend title.
#' @param quality Column with the INEI quality band (`quality` in
#'   [fa_estimate()]); `NULL` to ignore it.
#' @return A `ggplot` object.
#' @export
#' @examples
#' \dontrun{
#' p <- fa_indicator("pobreza_monetaria", 2024, by = "department")
#' fa_map(p, title = "Monetary poverty 2024", legend = "Poor people")
#' fa_map(p, breaks = c(0, .1, .2, .3, .4, .5), palette = "Purples")
#' }
fa_map <- function(x, value = "estimate", level = c("department", "district"), key = NULL,
                    base = NULL, percent = TRUE, title = NULL, geometry = NULL,
                    cache = fa_cache(), breaks = "quantile", n = 5, palette = "YlOrRd",
                    labels = "name", context = TRUE, legend = NULL, quality = "quality") {
  level <- match.arg(level)
  .need("sf", "for maps")
  .need("ggplot2", "for maps")
  if (!is.data.frame(x)) .abort("bad_input", "`x` must be a data frame.")
  if (!value %in% names(x)) .abort("not_found", "Column `%s` not found.", value)
  if (!is.numeric(x[[value]])) .abort("bad_input", "Column `%s` must be numeric.", value)
  labels <- match.arg(labels, c("name", "code", "none"))
  key <- key %||% intersect(c("department", "ubigeo_base", "ubigeo", "domain"), names(x))[1]
  if (is.na(key) || !key %in% names(x)) .abort("not_found", "No column with the area code; set `key`.")
  code <- .pad(x[[key]], if (level == "department") 2 else 6)
  if (anyDuplicated(code[!is.na(code)])) .abort("bad_input", "Several rows per area in `x`.")

  g <- geometry %||% fa_geometry(level, cache = cache)
  if (!inherits(g, "sf") || !all(c("code", "name") %in% names(g))) {
    .abort("bad_input", "`geometry` must be an sf object with `code` and `name`.")
  }
  if (level == "district" && !is.null(base)) g <- .dissolve(g, base)
  at <- match(g$code, code)
  g$fa_fill <- x[[value]][at]
  g$fa_ref <- if (!is.null(quality) && quality %in% names(x)) x[[quality]][at] %in% "referencial" else FALSE
  missing <- setdiff(code[!is.na(code)], g$code)
  if (length(missing)) {
    .warn("not_on_map", "%d area(s) of `x` are not on the map: %s.", length(missing),
          paste(utils::head(missing, 5), collapse = ", "))
  }

  crs <- 32718                                   # WGS 84 / UTM zone 18S
  g <- sf::st_transform(sf::st_make_valid(g), crs)
  fmt <- function(v) if (percent) paste0(.round_label(100 * v), "%") else .round_label(v)
  line <- if (level == "department") 0.25 else 0.05
  continuous <- identical(breaks, "continuous")
  if (!continuous) {
    cuts <- .map_breaks(g$fa_fill, breaks, n)
    k <- length(cuts) - 1L
    lab <- paste(fmt(cuts[-length(cuts)]), "\u2013", fmt(cuts[-1]))
    g$fa_class <- cut(g$fa_fill, cuts, labels = lab, include.lowest = TRUE)
    # The palest shade of a sequential palette is nearly white: skip it.
    cols <- stats::setNames(grDevices::hcl.colors(k + 1L, palette, rev = TRUE)[-1], lab)
  }
  p <- ggplot2::ggplot(g)

  box <- sf::st_bbox(g)
  pad <- 0.06 * max(box["xmax"] - box["xmin"], box["ymax"] - box["ymin"])
  lim_x <- c(box["xmin"] - pad, box["xmax"] + pad)
  lim_y <- c(box["ymin"] - pad, box["ymax"] + pad)
  if (context) {
    world <- .south_america(crs)
    p <- p + ggplot2::geom_sf(data = world[world$iso_a3 != "PER", ], fill = "#ececec",
                              colour = "#bdbdbd", linewidth = 0.2)
  }

  if (continuous) {
    p <- p + ggplot2::geom_sf(data = g, ggplot2::aes(fill = fa_fill), colour = "white", linewidth = line) +
      ggplot2::scale_fill_gradientn(colours = grDevices::hcl.colors(9, palette, rev = TRUE),
                                    na.value = "grey85", labels = fmt, name = legend)
  } else {
    p <- p + ggplot2::geom_sf(data = g, ggplot2::aes(fill = fa_class), colour = "white", linewidth = line) +
      ggplot2::scale_fill_manual(values = cols, na.value = "grey85", drop = FALSE, name = legend,
                                 na.translate = anyNA(g$fa_class),
                                 labels = function(v) ifelse(is.na(v), "Sin dato", v))
  }
  if (any(g$fa_ref)) {
    p <- p + ggplot2::geom_sf(data = g[g$fa_ref, ], fill = NA, colour = "#3f3f46",
                              linewidth = 0.35, linetype = "22")
  }
  if (level == "department" && labels != "none") {
    # Largest areas first, so a small one (Callao) never hides a large one
    # (Lima); text is white on dark fills and dark on light ones.
    area <- as.numeric(sf::st_area(g))
    big <- order(-area)
    big <- big[area[big] > 0.004 * sum(area)]
    pts <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(g)[big]))
    xy <- sf::st_coordinates(pts)
    fill <- if (continuous) {
      ramp <- grDevices::colorRampPalette(grDevices::hcl.colors(9, palette, rev = TRUE))(100)
      r <- range(g$fa_fill, na.rm = TRUE)
      ramp[pmax(1, pmin(100, round(1 + 99 * (g$fa_fill - r[1]) / max(diff(r), 1e-12))))]
    } else unname(cols[as.character(g$fa_class)])
    fill[is.na(fill)] <- "#d9d9d9"
    lum <- colSums(grDevices::col2rgb(fill[big]) * c(0.299, 0.587, 0.114)) / 255
    lab_df <- data.frame(fa_x = xy[, 1], fa_y = xy[, 2],
                         fa_label = paste0(if (labels == "name") .title_case(g$name[big]) else g$code[big],
                                           ifelse(g$fa_ref[big], "*", "")))
    # A thin halo of the opposite colour keeps names legible where they
    # cross into a neighbour.
    ink <- ifelse(lum < 0.5, "white", "#1f2937")
    halo <- ifelse(lum < 0.5, "#1f2937", "white")
    d <- 0.0011 * diff(lim_x)
    for (a in seq(0, 2 * pi, length.out = 9)[-9]) {
      p <- p + ggplot2::geom_text(data = transform(lab_df, fa_x = fa_x + d * cos(a), fa_y = fa_y + d * sin(a)),
                                  ggplot2::aes(fa_x, fa_y, label = fa_label), size = 2.3,
                                  colour = halo, fontface = "bold", alpha = 0.55)
    }
    p <- p + ggplot2::geom_text(data = lab_df, ggplot2::aes(fa_x, fa_y, label = fa_label),
                                size = 2.3, colour = ink, fontface = "bold")
  }
  if (context) p <- p + .north_arrow(lim_x, lim_y) + .scale_bar(lim_x, lim_y)
  p <- p + ggplot2::coord_sf(crs = crs, xlim = lim_x, ylim = lim_y, expand = FALSE, datum = NA) +
    ggplot2::labs(title = title, x = NULL, y = NULL,
                  caption = if (any(g$fa_ref)) "* Solo referencial (CV mayor a 15% o pocos casos)" else NULL) +
    ggplot2::theme_void(base_size = 10) +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = if (context) "#e8f1f8" else NA, colour = if (context) "#9ca3af" else NA, linewidth = 0.3),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.position = "inside", legend.position.inside = c(0.03, 0.03),
      legend.justification = c(0, 0),
      legend.background = ggplot2::element_rect(fill = "white", colour = "#d4d4d8", linewidth = 0.2),
      legend.margin = ggplot2::margin(5, 6, 5, 6),
      legend.key.size = grid::unit(0.42, "cm"),
      legend.title = ggplot2::element_text(face = "bold", size = 8.5),
      legend.text = ggplot2::element_text(size = 7.5),
      plot.title = ggplot2::element_text(face = "bold", size = 12, margin = ggplot2::margin(b = 6)),
      plot.caption = ggplot2::element_text(size = 7, colour = "#52525b", hjust = 0),
      plot.margin = ggplot2::margin(6, 6, 6, 6)
    )
  if (context) p <- p + .inset(world, crs, lim_x, lim_y)
  p
}

# Class limits: quantiles, round numbers or the user's own.
.map_breaks <- function(v, breaks, n) {
  v <- v[is.finite(v)]
  if (length(v) == 0L) return(c(0, 1))
  if (is.numeric(breaks)) {
    b <- sort(unique(breaks))
    if (min(v) < b[1]) b <- c(min(v), b)
    if (max(v) > b[length(b)]) b <- c(b, max(v))
    return(b)
  }
  breaks <- match.arg(breaks, c("quantile", "pretty"))
  b <- if (breaks == "quantile") unique(stats::quantile(v, seq(0, 1, length.out = n + 1), names = FALSE)) else
    pretty(v, n)
  b[1] <- min(b[1], min(v))
  b[length(b)] <- max(b[length(b)], max(v))
  if (length(b) < 2L) b <- c(min(v), max(v) + 1e-9)
  b
}

.round_label <- function(v) {
  d <- if (all(abs(v - round(v)) < 1e-9)) 0 else if (max(abs(v), na.rm = TRUE) >= 10) 0 else 1
  formatC(v, format = "f", digits = d, big.mark = ",")
}

.title_case <- function(x) {
  x <- tolower(x)
  x <- gsub("(^|[ -])([a-z\u00e1\u00e9\u00ed\u00f3\u00fa\u00f1])", "\\1\\U\\2", x, perl = TRUE)
  gsub(" (De|Del|La|Las|Los|Y) ", " \\L\\1 ", x, perl = TRUE)
}

.south_america <- function(crs) {
  f <- system.file("geo", "south_america.geojson", package = "faperu")
  sf::st_transform(sf::st_make_valid(sf::st_read(f, quiet = TRUE)), crs)
}

# A north arrow in the top right corner, drawn in map units.
.north_arrow <- function(lim_x, lim_y) {
  w <- 0.035 * diff(lim_x)
  cx <- lim_x[2] - 1.6 * w
  top <- lim_y[2] - 0.6 * w
  h <- 1.7 * w
  tri_l <- data.frame(fa_x = c(cx, cx - w / 2, cx), fa_y = c(top, top - h, top - 0.72 * h))
  tri_r <- data.frame(fa_x = c(cx, cx + w / 2, cx), fa_y = c(top, top - h, top - 0.72 * h))
  list(
    ggplot2::geom_polygon(data = tri_l, ggplot2::aes(fa_x, fa_y), fill = "#1f2937", colour = "#1f2937", linewidth = 0.3),
    ggplot2::geom_polygon(data = tri_r, ggplot2::aes(fa_x, fa_y), fill = "white", colour = "#1f2937", linewidth = 0.3),
    ggplot2::annotate("text", x = cx, y = top - h - 0.45 * w, label = "N", fontface = "bold", size = 3.2)
  )
}

# A scale bar in kilometres, bottom right, with round lengths.
.scale_bar <- function(lim_x, lim_y) {
  span <- diff(lim_x) / 1000
  len <- c(50, 100, 200, 250, 300, 400, 500, 1000)
  km <- len[which.min(abs(len - span / 4))]
  x0 <- lim_x[1] + 0.34 * diff(lim_x)
  x1 <- x0 + km * 1000
  y <- lim_y[1] + 0.045 * diff(lim_y)
  h <- 0.008 * diff(lim_y)
  half <- (x0 + x1) / 2
  bars <- data.frame(xmin = c(x0, half), xmax = c(half, x1), fill = c("#1f2937", "white"))
  list(
    ggplot2::annotate("rect", xmin = bars$xmin, xmax = bars$xmax, ymin = y, ymax = y + h,
                      fill = bars$fill, colour = "#1f2937", linewidth = 0.25),
    ggplot2::annotate("text", x = c(x0, half, x1), y = y + h + 0.018 * diff(lim_y),
                      label = c("0", format(km / 2), paste(km, "km")), size = 2.4)
  )
}

# South America with Peru in colour, top left over the Pacific.
.inset <- function(world, crs, lim_x, lim_y) {
  sa <- sf::st_transform(world, 4326)
  peru <- sa$iso_a3 == "PER"
  small <- ggplot2::ggplot(sa) +
    ggplot2::geom_sf(fill = ifelse(peru, "#0e7c86", "#d4d4d8"), colour = "white", linewidth = 0.1) +
    ggplot2::coord_sf(xlim = c(-82, -34), ylim = c(-56, 13), expand = FALSE, datum = NA) +
    ggplot2::theme_void() +
    ggplot2::theme(panel.background = ggplot2::element_rect(fill = "white", colour = "#9ca3af", linewidth = 0.3))
  w <- 0.24 * diff(lim_x)
  ggplot2::annotation_custom(ggplot2::ggplotGrob(small),
                             xmin = lim_x[1] + 0.02 * diff(lim_x), xmax = lim_x[1] + 0.02 * diff(lim_x) + w,
                             ymin = lim_y[2] - 0.02 * diff(lim_y) - 1.35 * w, ymax = lim_y[2] - 0.02 * diff(lim_y))
}

# Current district boundaries merged into the districts of the base census.
.dissolve <- function(g, base) {
  m <- suppressWarnings(fa_ubigeo(data.frame(u = g$code), "u", as.integer(format(Sys.Date(), "%Y")),
                                          base = base))
  g$base <- ifelse(is.na(m$ubigeo_base), g$code, m$ubigeo_base)
  g$base[m$ubigeo_status %in% "multi_parent"] <- NA
  several <- unique(g$base[duplicated(g$base) & !is.na(g$base)])
  if (length(several) == 0L) {
    g$code <- g$base
    return(g[, c("code", "name")])
  }
  one <- g[!g$base %in% several, ]
  one$code <- one$base
  merged <- lapply(several, function(b) {
    part <- g[g$base %in% b, ]
    keep <- part[part$code == b, ]
    sf::st_sf(code = b, name = if (nrow(keep)) keep$name[1] else part$name[1],
              geometry = sf::st_union(sf::st_make_valid(sf::st_geometry(part))))
  })
  rbind(one[, c("code", "name")], do.call(rbind, merged))
}
