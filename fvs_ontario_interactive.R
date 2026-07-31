# Interactive FVS Ontario workflow for RStudio.
# Run: source("path/to/runRforFVS/fvs_ontario_interactive.R")
# Then follow the menus in the RStudio Console.

script_directory <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
fvs_source_file <- tryCatch(sys.frame(1)$ofile, error = function(error) NULL)
if (!is.null(fvs_source_file) && nzchar(fvs_source_file)) {
  script_directory <- dirname(normalizePath(fvs_source_file, winslash = "/", mustWork = TRUE))
}
fvs_legacy_home <- Sys.getenv(
  "FVS_ONTARIO_LEGACY_HOME",
  unset = "C:/Program Files (x86)/FVSOntario"
)
source(file.path(script_directory, "fvs_species_yield.R"))
source(file.path(script_directory, "fvs_species_yield_ggplot.R"))

fvs_species_catalogue <- data.frame(
  label = c("Black spruce", "White spruce", "Jack pine", "White pine", "Red pine",
    "Trembling aspen", "Balsam fir", "White birch", "Tamarack"),
  natural_code = c(9L, 6L, 1L, 5L, 3L, 41L, 8L, 43L, 10L),
  planted_code = c(72L, 71L, 69L, 70L, 4L, NA_integer_, NA_integer_, NA_integer_, NA_integer_),
  default_sdi = c(815, 861, 680, 1087, 1087, 589, 1087, 680, 906),
  stringsAsFactors = FALSE
)

fvs_regeneration <- function(species, stems_per_ha, origin = c("natural", "planted")) {
  origin <- match.arg(origin)
  if (length(species) != length(stems_per_ha) || !length(species)) {
    stop("species and stems_per_ha must have the same non-zero length.", call. = FALSE)
  }
  species_key <- gsub("[^a-z0-9]+", "_", tolower(fvs_species_catalogue$label))
  requested_key <- gsub("[^a-z0-9]+", "_", tolower(species))
  matched <- match(requested_key, species_key)
  if (anyNA(matched)) {
    stop("Unknown species: ", paste(species[is.na(matched)], collapse = ", "),
      ". Use one of: ", paste(species_key, collapse = ", "), call. = FALSE)
  }
  species_code <- if (origin == "natural") {
    fvs_species_catalogue$natural_code[matched]
  } else {
    fvs_species_catalogue$planted_code[matched]
  }
  if (anyNA(species_code)) {
    stop("FVS Ontario has no planted species code configured for: ",
      paste(species[is.na(species_code)], collapse = ", "), call. = FALSE)
  }
  if (any(!is.finite(stems_per_ha)) || any(stems_per_ha <= 0)) {
    stop("stems_per_ha must contain positive numbers.", call. = FALSE)
  }
  data.frame(label = fvs_species_catalogue$label[matched], species_code = species_code,
    density = stems_per_ha, default_sdi = fvs_species_catalogue$default_sdi[matched],
    stringsAsFactors = FALSE)
}

fvs_species_defaults <- function(species, origin = c("natural", "planted")) {
  origin <- match.arg(origin)
  defaults <- fvs_regeneration(species, rep(1, length(species)), origin)
  defaults[c("label", "species_code", "default_sdi")]
}

fvs_thin <- function(trigger_value, trigger = c("age", "year", "basal_area", "top_height", "qmd"),
                     direction = c("below", "above"),
                     target, target_type = c("basal_area", "stems"),
                     min_dbh_cm = 0, max_dbh_cm = 999, min_height_m = 0,
                     max_height_m = 999, cutting_efficiency = 1) {
  trigger <- match.arg(trigger)
  direction <- match.arg(direction)
  target_type <- match.arg(target_type)
  if (trigger != "age" || direction != "below" || target_type != "stems") {
    stop(
      "Only the SimProg-validated treatment is currently supported: trigger = 'age', direction = 'below', and target_type = 'stems'.",
      call. = FALSE
    )
  }
  numeric_values <- c(trigger_value, target, min_dbh_cm, max_dbh_cm,
    min_height_m, max_height_m, cutting_efficiency)
  if (any(!is.finite(numeric_values))) stop("Treatment values must be finite numbers.", call. = FALSE)
  if (target <= 0 || min_dbh_cm < 0 || max_dbh_cm <= min_dbh_cm ||
      min_height_m < 0 || max_height_m <= min_height_m ||
      cutting_efficiency <= 0 || cutting_efficiency > 1) {
    stop("Treatment target and ranges are invalid.", call. = FALSE)
  }

  structure(list(
    lines = c(
      "IF               999",
      sprintf("AGE GE %.6f AND AGE LE (%.6f+CENDYEAR-YEAR)", trigger_value, trigger_value),
      "THEN",
      sprintf("%-10s%10s%10.3f%10.3f%10.3f%10.3f%10.3f%10.3f",
        "THINBTA", "", target, cutting_efficiency, min_dbh_cm,
        max_dbh_cm, min_height_m, max_height_m),
      "ENDIF"
    ),
    trigger = trigger, trigger_value = trigger_value, direction = direction,
    target = target, target_type = target_type
  ), class = "fvs_treatment")
}

fvs_sdimax <- function(species, maximum_sdi = NULL, origin = c("natural", "planted"),
                       mortality_threshold = NULL, maximum_density_threshold = NULL) {
  origin <- match.arg(origin)
  if (!length(species)) stop("species must contain at least one species.", call. = FALSE)
  species_defaults <- fvs_species_defaults(species, origin)
  if (is.null(maximum_sdi)) maximum_sdi <- species_defaults$default_sdi
  if (length(species) != length(maximum_sdi) || any(!is.finite(maximum_sdi)) || any(maximum_sdi <= 0)) {
    stop("species and maximum_sdi must have the same length, with positive SDI values.", call. = FALSE)
  }
  if (!is.null(mortality_threshold) &&
      (!is.numeric(mortality_threshold) || length(mortality_threshold) != 1L ||
       !is.finite(mortality_threshold) || mortality_threshold < 10)) {
    stop("mortality_threshold must be one number greater than or equal to 10.", call. = FALSE)
  }
  if (!is.null(maximum_density_threshold) &&
      (!is.numeric(maximum_density_threshold) || length(maximum_density_threshold) != 1L ||
       !is.finite(maximum_density_threshold) || maximum_density_threshold > 95)) {
    stop("maximum_density_threshold must be one number less than or equal to 95.", call. = FALSE)
  }

  species_codes <- species_defaults$species_code
  threshold_field <- function(value) if (is.null(value)) "" else sprintf("%.3f", value)
  lines <- vapply(seq_along(species_codes), function(index) {
    sprintf("SDIMAX%10d%10.3f%10s%10s%10s%10s",
      species_codes[index], maximum_sdi[index], "", "",
      if (index == 1L) threshold_field(mortality_threshold) else "",
      if (index == 1L) threshold_field(maximum_density_threshold) else "")
  }, character(1L))

  structure(list(lines = lines, species = species, species_codes = species_codes,
    maximum_sdi = maximum_sdi, origin = origin, modifier_type = "sdimax"), class = "fvs_stand_modifier")
}

fvs_bamax <- function(maximum_basal_area_ft2_ac) {
  if (!is.numeric(maximum_basal_area_ft2_ac) || length(maximum_basal_area_ft2_ac) != 1L ||
      !is.finite(maximum_basal_area_ft2_ac) || maximum_basal_area_ft2_ac <= 0) {
    stop("maximum_basal_area_ft2_ac must be one positive number.", call. = FALSE)
  }
  structure(list(
    lines = sprintf("BAMAX%12.3f", maximum_basal_area_ft2_ac),
    maximum_basal_area_ft2_ac = maximum_basal_area_ft2_ac,
    modifier_type = "bamax"
  ), class = "fvs_stand_modifier")
}

fvs_treatment_lines <- function(treatments) {
  if (is.null(treatments)) return(character())
  if (inherits(treatments, "fvs_treatment")) treatments <- list(treatments)
  if (!is.list(treatments) || !length(treatments) ||
      any(!vapply(treatments, inherits, logical(1L), what = "fvs_treatment"))) {
    stop("treatments must be an fvs_thin() result or a list of fvs_thin() results.", call. = FALSE)
  }
  unlist(lapply(treatments, function(treatment) c("", treatment$lines)), use.names = FALSE)
}

fvs_stand_modifier_lines <- function(stand_modifiers) {
  if (is.null(stand_modifiers)) return(character())
  if (inherits(stand_modifiers, "fvs_stand_modifier")) stand_modifiers <- list(stand_modifiers)
  if (!is.list(stand_modifiers) || !length(stand_modifiers) ||
      any(!vapply(stand_modifiers, inherits, logical(1L), what = "fvs_stand_modifier"))) {
    stop("stand_modifiers must be an fvs_sdimax() or fvs_bamax() result, or a list of them.", call. = FALSE)
  }
  modifier_types <- vapply(stand_modifiers, `[[`, character(1L), "modifier_type")
  if (all(c("bamax", "sdimax") %in% modifier_types)) {
    stop("Do not combine BAMAX and SDIMAX: FVS ignores SDIMAX when BAMAX is set.", call. = FALSE)
  }
  unlist(lapply(stand_modifiers, function(modifier) c("", modifier$lines)), use.names = FALSE)
}

ask_text <- function(prompt, default = NULL) {
  answer <- readline(if (is.null(default)) paste0(prompt, ": ") else paste0(prompt, " [", default, "]: "))
  if (!nzchar(answer) && !is.null(default)) default else answer
}

ask_number <- function(prompt, default, minimum = -Inf) {
  repeat {
    value <- suppressWarnings(as.numeric(ask_text(prompt, as.character(default))))
    if (length(value) == 1L && !is.na(value) && value >= minimum) return(value)
    message("Enter a number greater than or equal to ", minimum, ".")
  }
}

choose_regeneration_species <- function(origin) {
  available <- if (origin == "planted") !is.na(fvs_species_catalogue$planted_code) else rep(TRUE, nrow(fvs_species_catalogue))
  catalogue <- fvs_species_catalogue[available, ]
  selections <- list()
  repeat {
    choice <- utils::menu(c(catalogue$label, "Finish species selection"), title = "Select a species")
    if (choice == 0L || choice == nrow(catalogue) + 1L) break
    selected <- catalogue[choice, ]
    density <- ask_number(paste0("Initial stems/ha for ", selected$label), 1000, minimum = 1)
    species_code <- if (origin == "planted") selected$planted_code else selected$natural_code
    selections[[length(selections) + 1L]] <- data.frame(
      label = selected$label, species_code = species_code, density = density,
      stringsAsFactors = FALSE
    )
  }
  if (!length(selections)) stop("Select at least one species.", call. = FALSE)
  do.call(rbind, selections)
}

run_fvs_ontario_scenario <- function(run_id, description, output_directory,
                                     inventory_year, forest_type, site_species_code, site_index,
                                     projection_years = 100, time_step_years = 5,
                                     inventory_file = NULL, regeneration = NULL,
                                     origin = c("natural", "planted"),
                                     stand_modifiers = NULL,
                                     treatments = NULL,
                                     save_plots = FALSE,
                                     fvs_executable = file.path(fvs_legacy_home, "Model", "FVSOntario.exe")) {
  origin <- match.arg(origin)
  if (!file.exists(fvs_executable)) stop("FVS executable was not found: ", fvs_executable, call. = FALSE)
  if (!is.null(inventory_file) && !file.exists(inventory_file)) stop("Inventory file was not found: ", inventory_file, call. = FALSE)
  if (is.null(inventory_file) && (is.null(regeneration) || !nrow(regeneration))) {
    stop("Provide either an inventory_file or a regeneration table.", call. = FALSE)
  }
  if (projection_years %% time_step_years != 0) stop("projection_years must be divisible by time_step_years.", call. = FALSE)

  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  output_directory <- normalizePath(output_directory, winslash = "/", mustWork = TRUE)
  run_stem <- tolower(gsub("[^A-Za-z0-9_]+", "_", run_id))
  key_file <- file.path(output_directory, paste0(run_stem, ".key"))
  response_file <- file.path(output_directory, paste0(run_stem, ".rsp"))
  output_file <- file.path(output_directory, paste0(run_stem, ".out"))
  tree_list_file <- file.path(output_directory, paste0(run_stem, ".lst"))
  summary_file <- file.path(output_directory, paste0(run_stem, ".sum"))
  species_yield_file <- file.path(output_directory, paste0(run_stem, "_species_yield.csv"))
  stand_yield_file <- file.path(output_directory, paste0(run_stem, "_stand_yield.csv"))
  ggplot_file <- file.path(output_directory, paste0(run_stem, "_species_yield_ggplot.png"))
  run_artifacts <- c(
    output_file, tree_list_file, summary_file, species_yield_file, stand_yield_file, ggplot_file
  )
  unlink(run_artifacts)
  remaining_artifacts <- run_artifacts[file.exists(run_artifacts)]
  if (length(remaining_artifacts)) {
    stop(
      "Cannot replace existing FVS output files. Close any application using: ",
      paste(remaining_artifacts, collapse = ", "),
      call. = FALSE
    )
  }

  key_lines <- c(
    "* Created by fvs_ontario_interactive.R", "ECHOSUM", "SCREEN",
    "TREELIST           0                   0", "",
    "STDIDENT", sprintf("%-20s%s", run_id, description),
    sprintf("TIMEINT%23d", time_step_years),
    sprintf("TIMEINT%13d%10d", 1, time_step_years),
    sprintf("NUMCYCLE%12d", projection_years / time_step_years), "",
    sprintf("STDINFO%13d%20d", forest_type, 0),
    sprintf("SITECODE%12d%9.1f", site_species_code, site_index),
    fvs_stand_modifier_lines(stand_modifiers), ""
  )

  if (!is.null(inventory_file)) {
    key_lines <- c(key_lines,
      "DESIGN            -1         1         0",
      sprintf("INVYEAR%13d", inventory_year), sprintf("ESTAB%13d", inventory_year),
      "STOCKADJ          -1", "END", "",
      "TREEFMT",
      "(I4,T1,I7,F6.0,I1,A3,F5.1,F4.1,F5.1,F5.1,F5.1,I1,I2,I2,I2,I2,I2,I2,I1,I1,",
      "I2,I3,I3,I1,I1,F3.0)", ""
    )
  } else {
    regeneration_lines <- vapply(seq_len(nrow(regeneration)), function(index) {
      row <- regeneration[index, ]
      if (origin == "natural") {
        sprintf("NATURAL%13d%10d%10.0f%10d", inventory_year, row$species_code, row$density, 100)
      } else {
        sprintf("PLANT%15d%8d%10.0f%10d%10d%10.1f", inventory_year, row$species_code, row$density, 100, 2, 0.4)
      }
    }, character(1L))
    key_lines <- c(key_lines,
      "NOTREES", sprintf("INVYEAR%13d", inventory_year), sprintf("ESTAB%13d", inventory_year),
      "STOCKADJ        -1.0", regeneration_lines, "END", ""
    )
  }

  key_lines <- c(key_lines, fvs_treatment_lines(treatments), "", "PROCESS", "STOP")
  writeLines(key_lines, key_file, useBytes = TRUE)

  staged_inventory_file <- NULL
  if (!is.null(inventory_file)) {
    inventory_extension <- tools::file_ext(inventory_file)
    staged_inventory_file <- tempfile(
      pattern = paste0(run_stem, "_input_"),
      tmpdir = output_directory,
      fileext = if (nzchar(inventory_extension)) paste0(".", inventory_extension) else ""
    )
    if (!isTRUE(file.copy(inventory_file, staged_inventory_file))) {
      stop("Could not stage inventory file for FVS: ", inventory_file, call. = FALSE)
    }
  }

  response_lines <- c(
    normalizePath(key_file, winslash = "\\", mustWork = TRUE),
    if (is.null(staged_inventory_file)) "NUL" else normalizePath(staged_inventory_file, winslash = "\\", mustWork = TRUE),
    normalizePath(output_file, winslash = "\\", mustWork = FALSE),
    normalizePath(tree_list_file, winslash = "\\", mustWork = FALSE),
    normalizePath(summary_file, winslash = "\\", mustWork = FALSE), "NUL"
  )
  writeLines(response_lines, response_file, useBytes = TRUE)

  message("Running FVS Ontario...")
  fvs_console <- suppressWarnings(system2(
    fvs_executable, stdin = response_file, stdout = TRUE, stderr = TRUE
  ))
  fvs_status <- attr(fvs_console, "status")
  if (is.null(fvs_status)) fvs_status <- 0L
  if (as.integer(fvs_status) != 0L) {
    stop(
      "FVS Ontario exited with status ", fvs_status,
      ". No yield tables were created. Inspect: ", output_file,
      call. = FALSE
    )
  }
  expected_files <- c(output_file, tree_list_file, summary_file)
  if (!all(file.exists(expected_files)) || any(file.info(expected_files)$size <= 0L)) {
    stop("FVS did not write all expected report files. Inspect: ", key_file, call. = FALSE)
  }

  extract_yield <- get("extract_fvs_species_yield", mode = "function")
  plot_yield <- get("plot_fvs_species_yield", mode = "function")
  extracted <- extract_yield(tree_list_file, output_directory, write_base_plot = save_plots)
  plot <- plot_yield(extracted$files[["species_csv"]], output_file = if (save_plots) ggplot_file else NULL)
  message("Completed. Results: ", output_directory)
  invisible(list(files = c(key = key_file, response = response_file, out = output_file,
    tree_list = tree_list_file, summary = summary_file, species_yield = extracted$files[["species_csv"]],
    stand_yield = extracted$files[["stand_csv"]], plot = if (save_plots) ggplot_file else NA_character_),
    species_yield = extracted$species_yield, stand_yield = extracted$stand_yield, plot = plot))
}

fvs_run <- function(species, stems_per_ha, origin = c("natural", "planted"),
                    site_index, site_species = species[1L], site_species_origin = origin,
                    inventory_year = 2026,
                    projection_years = 100, time_step_years = 5,
                    run_id = "fvs_run", output_directory = file.path(getwd(), "fvs_output"),
                    stand_modifiers = NULL,
                    treatments = NULL,
                    save_plots = FALSE,
                    fvs_executable = file.path(fvs_legacy_home, "Model", "FVSOntario.exe")) {
  origin <- match.arg(origin)
  site_species_origin <- match.arg(site_species_origin, c("natural", "planted"))
  regeneration <- fvs_regeneration(species, stems_per_ha, origin)
  site_species_row <- fvs_regeneration(site_species, 1, site_species_origin)
  run_fvs_ontario_scenario(
    run_id = run_id, description = "FVS R scenario", output_directory = output_directory,
    inventory_year = inventory_year, forest_type = 915,
    site_species_code = site_species_row$species_code, site_index = site_index,
    projection_years = projection_years, time_step_years = time_step_years,
    regeneration = regeneration, origin = origin, stand_modifiers = stand_modifiers,
    treatments = treatments, save_plots = save_plots,
    fvs_executable = fvs_executable
  )
}

fvs_load_run <- function(tree_list_file,
                         output_directory = dirname(tree_list_file),
                         save_plots = FALSE) {
  if (!file.exists(tree_list_file)) {
    stop("FVS tree-list file was not found: ", tree_list_file, call. = FALSE)
  }
  dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  extract_yield <- get("extract_fvs_species_yield", mode = "function")
  build_plot <- get("build_fvs_species_yield_plot", mode = "function")
  extracted <- extract_yield(tree_list_file, output_directory, write_base_plot = save_plots)
  plot <- build_plot(extracted$species_yield, extracted$stand_yield)
  plot_file <- file.path(
    output_directory,
    paste0(tools::file_path_sans_ext(basename(tree_list_file)), "_species_yield_ggplot.png")
  )
  if (save_plots) ggplot2::ggsave(plot_file, plot = plot, width = 10, height = 8, dpi = 180)

  run_stem <- tools::file_path_sans_ext(basename(tree_list_file))
  files <- c(
    key = file.path(dirname(tree_list_file), paste0(run_stem, ".key")),
    out = file.path(dirname(tree_list_file), paste0(run_stem, ".out")),
    tree_list = tree_list_file,
    summary = file.path(dirname(tree_list_file), paste0(run_stem, ".sum")),
    species_yield = extracted$files[["species_csv"]],
    stand_yield = extracted$files[["stand_csv"]],
    plot = if (save_plots) plot_file else NA_character_
  )
  invisible(list(files = files, species_yield = extracted$species_yield,
    stand_yield = extracted$stand_yield, plot = plot))
}

run_interactive_fvs_ontario <- function() {
  scenario_type <- utils::menu(c("New regenerated stand", "Existing inventory (.tre)"), title = "FVS Ontario scenario type")
  if (scenario_type == 0L) return(invisible(NULL))

  run_id <- ask_text("Run name", paste0("scenario_", format(Sys.time(), "%Y%m%d_%H%M%S")))
  output_directory <- ask_text("Output folder", file.path(getwd(), "fvs_runs", run_id))
  inventory_year <- as.integer(ask_number("Inventory/establishment year", 2026, minimum = 1900))
  projection_years <- as.integer(ask_number("Projection length (years)", 100, minimum = 5))
  time_step_years <- as.integer(ask_number("Output interval (years)", 5, minimum = 1))
  site_index <- ask_number("Site index (m)", 18, minimum = 1)

  if (scenario_type == 1L) {
    origin_choice <- utils::menu(c("Natural regeneration", "Planted regeneration"), title = "Regeneration origin")
    if (origin_choice == 0L) return(invisible(NULL))
    origin <- c("natural", "planted")[origin_choice]
    regeneration <- choose_regeneration_species(origin)
    site_species_choice <- utils::menu(regeneration$label, title = "Select the site species")
    if (site_species_choice == 0L) return(invisible(NULL))
    site_species_code <- regeneration$species_code[site_species_choice]
    return(run_fvs_ontario_scenario(
      run_id = run_id, description = "Interactive regeneration scenario", output_directory = output_directory,
      inventory_year = inventory_year, forest_type = 915, site_species_code = site_species_code, site_index = site_index,
      projection_years = projection_years, time_step_years = time_step_years,
      regeneration = regeneration, origin = origin, save_plots = TRUE
    ))
  }

  inventory_file <- ask_text("Full path to .tre inventory", file.path(fvs_legacy_home, "Work", "WhPinemx.tre"))
  site_species_code <- as.integer(ask_number("FVS site species code", 5, minimum = 1))
  run_fvs_ontario_scenario(
    run_id = run_id, description = "Interactive inventory scenario", output_directory = output_directory,
    inventory_year = inventory_year, forest_type = 915, site_species_code = site_species_code, site_index = site_index,
    projection_years = projection_years, time_step_years = time_step_years,
    inventory_file = inventory_file, save_plots = TRUE
  )
}

message("Ready. Use fvs_run(...) for an argument-driven run or run_interactive_fvs_ontario() for menus.")
