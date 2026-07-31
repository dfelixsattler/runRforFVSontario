# Plot FVS species yield-over-age CSV files with ggplot2.
# Usage in R:
# source("fvs_species_yield_ggplot.R")
# plot_fvs_species_yield("multi_species_whpinemx_species_yield.csv")

build_fvs_species_yield_plot <- function(species_yield, stand_yield,
                                         metric = c("gross_merchantable", "total_volume", "basal_area", "stems", "all")) {
  metric <- match.arg(metric)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("This plot requires ggplot2. Install it once with install.packages('ggplot2').", call. = FALSE)
  }
  required_columns <- c("age", "stems_per_ha", "gross_merchantable_m3_ha", "total_volume_m3_ha", "basal_area_m2_ha")
  if (!all(required_columns %in% names(species_yield)) || !all(required_columns %in% names(stand_yield))) {
    stop("The CSV files do not have the expected FVS yield columns.", call. = FALSE)
  }

  species_long <- rbind(
    data.frame(age = species_yield$age, species = species_yield$species,
      metric_type = "Stems", value = species_yield$stems_per_ha),
    data.frame(age = species_yield$age, species = species_yield$species,
      metric_type = "Gross merchantable volume", value = species_yield$gross_merchantable_m3_ha),
    data.frame(age = species_yield$age, species = species_yield$species,
      metric_type = "Total volume", value = species_yield$total_volume_m3_ha),
    data.frame(age = species_yield$age, species = species_yield$species,
      metric_type = "Basal area", value = species_yield$basal_area_m2_ha)
  )
  stand_long <- rbind(
    data.frame(age = stand_yield$age, metric_type = "Stems", value = stand_yield$stems_per_ha),
    data.frame(age = stand_yield$age, metric_type = "Gross merchantable volume",
      value = stand_yield$gross_merchantable_m3_ha),
    data.frame(age = stand_yield$age, metric_type = "Total volume",
      value = stand_yield$total_volume_m3_ha),
    data.frame(age = stand_yield$age, metric_type = "Basal area", value = stand_yield$basal_area_m2_ha)
  )

  metric_labels <- c(
    gross_merchantable = "Gross merchantable volume",
    total_volume = "Total volume",
    basal_area = "Basal area",
    stems = "Stems"
  )
  if (metric != "all") {
    species_long <- species_long[species_long$metric_type == metric_labels[[metric]], ]
    stand_long <- stand_long[stand_long$metric_type == metric_labels[[metric]], ]
  }

  age_column <- rlang::sym("age")
  value_column <- rlang::sym("value")
  species_column <- rlang::sym("species")
  ggplot2::ggplot(species_long, ggplot2::aes(
    x = !!age_column, y = !!value_column, colour = !!species_column
  )) +
    ggplot2::geom_line(linewidth = 0.9, na.rm = TRUE) +
    ggplot2::geom_line(data = stand_long,
      ggplot2::aes(x = !!age_column, y = !!value_column), inherit.aes = FALSE,
      colour = "black", linewidth = 0.9, linetype = "dashed") +
    ggplot2::facet_wrap(~metric_type, ncol = 1, scales = "free_y") +
    ggplot2::labs(
      title = "FVS yield over age by species",
      subtitle = "Dashed black line: stand total",
      x = "Stand age (years)",
      y = if (metric == "stems") "Stems/ha" else if (metric == "basal_area") expression("Basal area (" * m^2 * "/ha)") else expression("Volume (" * m^3 * "/ha)"),
      colour = "Species"
    ) +
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.grid.major = ggplot2::element_line(colour = "grey85"),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", colour = "black"),
      text = ggplot2::element_text(colour = "black"),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA)
    )
}

plot_fvs_yield <- function(results,
                           metric = c("gross_merchantable", "total_volume", "basal_area", "stems", "all")) {
  if (!all(c("species_yield", "stand_yield") %in% names(results))) {
    stop("results must be returned by fvs_run() or run_fvs_ontario_scenario().", call. = FALSE)
  }
  build_fvs_species_yield_plot(results$species_yield, results$stand_yield, metric = metric)
}

plot_fvs_scenario_comparison <- function(baseline_results, treatment_results,
                                         baseline_label = "Unthinned", treatment_label = "Thinned",
                                         metric = c("gross_merchantable", "total_volume", "basal_area", "stems", "all")) {
  metric <- match.arg(metric)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("This plot requires ggplot2. Install it once with install.packages('ggplot2').", call. = FALSE)
  }
  required_columns <- c("age", "stems_per_ha", "gross_merchantable_m3_ha", "total_volume_m3_ha", "basal_area_m2_ha")
  baseline_yield <- baseline_results$stand_yield
  treatment_yield <- treatment_results$stand_yield
  if (is.null(baseline_yield) || is.null(treatment_yield) ||
      !all(required_columns %in% names(baseline_yield)) ||
      !all(required_columns %in% names(treatment_yield))) {
    stop("Both inputs must be results returned by fvs_run() or fvs_load_run().", call. = FALSE)
  }

  make_long <- function(stand_yield, scenario) {
    rbind(
      data.frame(age = stand_yield$age, scenario = scenario, metric_type = "Stems/ha",
        value = stand_yield$stems_per_ha),
      data.frame(age = stand_yield$age, scenario = scenario, metric_type = "Gross merchantable volume (m3/ha)",
        value = stand_yield$gross_merchantable_m3_ha),
      data.frame(age = stand_yield$age, scenario = scenario, metric_type = "Total volume (m3/ha)",
        value = stand_yield$total_volume_m3_ha),
      data.frame(age = stand_yield$age, scenario = scenario, metric_type = "Basal area (m2/ha)",
        value = stand_yield$basal_area_m2_ha)
    )
  }
  comparison <- rbind(
    make_long(baseline_yield, baseline_label),
    make_long(treatment_yield, treatment_label)
  )
  metric_labels <- c(
    gross_merchantable = "Gross merchantable volume (m3/ha)",
    total_volume = "Total volume (m3/ha)",
    basal_area = "Basal area (m2/ha)",
    stems = "Stems/ha"
  )
  if (metric != "all") {
    comparison <- comparison[comparison$metric_type == metric_labels[[metric]], ]
  }

  ggplot2::ggplot(comparison, ggplot2::aes(
    x = !!rlang::sym("age"),
    y = !!rlang::sym("value"),
    colour = !!rlang::sym("scenario")
  )) +
    ggplot2::geom_line(linewidth = 1, na.rm = TRUE) +
    ggplot2::facet_wrap(~metric_type, ncol = 1, scales = "free_y") +
    ggplot2::labs(
      title = "FVS treatment comparison",
      subtitle = "Standing totals after treatment",
      x = "Stand age (years)",
      y = NULL,
      colour = "Scenario"
    ) +
    ggplot2::scale_colour_manual(
      values = stats::setNames(c("grey35", "#007C91"), c(baseline_label, treatment_label)),
      breaks = c(baseline_label, treatment_label)
    ) +
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

plot_fvs_species_yield <- function(species_csv,
                                   stand_csv = sub("_species_yield\\.csv$", "_stand_yield.csv", species_csv),
                                   output_file = NULL) {
  if (!file.exists(species_csv) || !file.exists(stand_csv)) {
    stop("Both species and stand yield CSV files are required.", call. = FALSE)
  }
  plot <- build_fvs_species_yield_plot(
    read.csv(species_csv, stringsAsFactors = FALSE),
    read.csv(stand_csv, stringsAsFactors = FALSE)
  )

  if (!is.null(output_file)) {
    ggplot2::ggsave(output_file, plot = plot, width = 10, height = 8, dpi = 180)
    message("Wrote: ", output_file)
  }
  invisible(plot)
}

command_arguments <- commandArgs(trailingOnly = TRUE)
if (length(command_arguments) == 2L) {
  plot_fvs_species_yield(command_arguments[1L], command_arguments[2L])
}