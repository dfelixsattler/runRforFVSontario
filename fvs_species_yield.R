# Extract species and stand yield-over-age tables from an FVS Ontario .lst file.
# Usage in R: source("fvs_species_yield.R"); extract_fvs_species_yield("multi_species_whpinemx.lst")

parse_number <- function(value) {
  suppressWarnings(as.numeric(value))
}

extract_fvs_species_yield <- function(lst_file, output_directory = dirname(lst_file), write_base_plot = TRUE) {
  if (!file.exists(lst_file)) {
    stop("FVS tree-list file was not found: ", lst_file, call. = FALSE)
  }

  lines <- readLines(lst_file, warn = FALSE)
  has_year_marker <- grepl("YEAR:[[:space:]]*[0-9]{4}|^[[:space:]]*-999[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]{4}", lines, perl = TRUE)
  if (!any(has_year_marker)) {
    stop("No COMPLETE TREE LIST year markers were found in: ", lst_file, call. = FALSE)
  }

  records <- list()
  current_year <- NA_integer_
  record_count <- 0L

  for (index in seq_along(lines)) {
    year_match <- regexpr("YEAR:[[:space:]]*([0-9]{4})", lines[index], perl = TRUE)
    if (year_match[1] != -1L) {
      current_year <- as.integer(sub(".*YEAR:[[:space:]]*([0-9]{4}).*", "\\1", lines[index], perl = TRUE))
      next
    }
    legacy_year_match <- regexpr("^[[:space:]]*-999[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([0-9]{4})", lines[index], perl = TRUE)
    if (legacy_year_match[1] != -1L) {
      current_year <- as.integer(sub("^[[:space:]]*-999[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([0-9]{4}).*", "\\1", lines[index], perl = TRUE))
      next
    }

    is_inventory_record <- grepl("^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[A-Z]{2,3}[[:space:]]+[0-9]+", lines[index])
    is_regeneration_record <- grepl("^[[:space:]]*ES[0-9]+[[:space:]]+[0-9]+[[:space:]]+[A-Z]{2,3}[[:space:]]+[0-9]+", lines[index])
    if (is.na(current_year) || (!is_inventory_record && !is_regeneration_record)) {
      next
    }

    first_line_fields <- strsplit(trimws(lines[index]), "[[:space:]]+")[[1L]]
    record_line <- if (length(first_line_fields) < 21L && index < length(lines)) {
      paste(lines[index], lines[index + 1L])
    } else {
      lines[index]
    }
    fields <- strsplit(trimws(record_line), "[[:space:]]+")[[1L]]
    if (length(fields) < 21L) {
      next
    }

    trees_per_ha <- parse_number(fields[8L])
    dbh_cm <- parse_number(fields[10L])
    total_volume_m3_per_tree <- parse_number(fields[19L])
    merchantable_m3_per_tree <- parse_number(fields[20L])
    if (anyNA(c(trees_per_ha, dbh_cm, merchantable_m3_per_tree, total_volume_m3_per_tree))) {
      next
    }

    record_count <- record_count + 1L
    records[[record_count]] <- data.frame(
      year = current_year,
      species = fields[3L],
      stems_per_ha = trees_per_ha,
      gross_merchantable_m3_ha = trees_per_ha * merchantable_m3_per_tree,
      total_volume_m3_ha = trees_per_ha * total_volume_m3_per_tree,
      basal_area_m2_ha = trees_per_ha * pi * (dbh_cm / 200)^2,
      stringsAsFactors = FALSE
    )
  }

  if (!length(records)) {
    stop("No FVS tree records could be parsed. Run FVS with TREELIST 0 0.", call. = FALSE)
  }

  tree_yield <- do.call(rbind, records)
  initial_year <- min(tree_yield$year)
  species_yield <- aggregate(
    cbind(stems_per_ha, gross_merchantable_m3_ha, total_volume_m3_ha, basal_area_m2_ha) ~ year + species,
    data = tree_yield,
    FUN = sum
  )
  species_yield$age <- species_yield$year - initial_year
  species_yield <- species_yield[, c("year", "age", "species", "stems_per_ha", "gross_merchantable_m3_ha", "total_volume_m3_ha", "basal_area_m2_ha")]
  species_yield <- species_yield[order(species_yield$year, species_yield$species), ]

  stand_yield <- aggregate(
    cbind(stems_per_ha, gross_merchantable_m3_ha, total_volume_m3_ha, basal_area_m2_ha) ~ year + age,
    data = species_yield,
    FUN = sum
  )
  stand_yield <- stand_yield[order(stand_yield$year), ]

  file_stem <- tools::file_path_sans_ext(basename(lst_file))
  species_csv <- file.path(output_directory, paste0(file_stem, "_species_yield.csv"))
  stand_csv <- file.path(output_directory, paste0(file_stem, "_stand_yield.csv"))
  plot_file <- file.path(output_directory, paste0(file_stem, "_yield_over_age.png"))
  write.csv(species_yield, species_csv, row.names = FALSE)
  write.csv(stand_yield, stand_csv, row.names = FALSE)

  if (write_base_plot) {
    species <- sort(unique(species_yield$species))
    colours <- grDevices::hcl.colors(length(species), palette = "Dark 3")
    grDevices::png(plot_file, width = 1600, height = 850, res = 150)
    graphics::par(mfrow = c(1, 2), mar = c(4, 4, 3, 1), las = 1)
    for (metric in c("gross_merchantable_m3_ha", "total_volume_m3_ha")) {
      y_limit <- range(c(species_yield[[metric]], stand_yield[[metric]]), finite = TRUE)
      graphics::plot(stand_yield$age, stand_yield[[metric]], type = "n",
        xlab = "Stand age (years)", ylab = "Volume (m3/ha)", ylim = y_limit,
        main = if (metric == "gross_merchantable_m3_ha") "Gross merchantable volume" else "Total volume")
      for (species_index in seq_along(species)) {
        rows <- species_yield$species == species[species_index]
        graphics::lines(species_yield$age[rows], species_yield[[metric]][rows],
          col = colours[species_index], lwd = 2)
      }
      graphics::lines(stand_yield$age, stand_yield[[metric]], lwd = 3, lty = 2)
      graphics::legend("topleft", legend = c(species, "Stand total"),
        col = c(colours, "black"), lwd = c(rep(2, length(species)), 3),
        lty = c(rep(1, length(species)), 2), bty = "n", cex = 0.8)
    }
    grDevices::dev.off()
  }

  message("Parsed ", record_count, " tree records from ", length(unique(tree_yield$year)), " projection years.")
  message("Wrote: ", species_csv)
  message("Wrote: ", stand_csv)
  if (write_base_plot) message("Wrote: ", plot_file)
  invisible(list(species_yield = species_yield, stand_yield = stand_yield,
    files = c(species_csv = species_csv, stand_csv = stand_csv,
      plot = if (write_base_plot) plot_file else NA_character_)))
}

command_arguments <- commandArgs(trailingOnly = TRUE)
if (length(command_arguments)) {
  extract_fvs_species_yield(command_arguments[1L])
}