#!/usr/bin/env Rscript

# 01_cleaning.R
# Reads the HRD CSV, filters to US influenza admissions, validates the result,
# writes cleaned CSV to output/data/01_cleaning/, and saves an epicurve PNG.

suppressPackageStartupMessages({
  if (!requireNamespace("readr", quietly = TRUE)) stop("Package 'readr' is required")
  if (!requireNamespace("dplyr", quietly = TRUE)) stop("Package 'dplyr' is required")
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Package 'ggplot2' is required")
  if (!requireNamespace("lubridate", quietly = TRUE)) stop("Package 'lubridate' is required")
})

library(readr)
library(dplyr)
library(ggplot2)
library(lubridate)

# Resolve the project root from the script location.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grepl("^--file=", args)]
if (length(script_arg) > 0) {
  script_path <- sub("^--file=", "", script_arg[1])
} else {
  script_path <- "USE-ME/OMI/scripts/01_cleaning.R"
}
script_path <- normalizePath(script_path, winslash = "/", mustWork = FALSE)
script_dir <- dirname(script_path)
project_root <- if (basename(script_dir) == "scripts") dirname(script_dir) else script_dir

infile <- file.path(project_root, "data", "Weekly Hospital Respiratory Data (HRD) Metrics by Jurisdiction.csv")
out_data_dir <- file.path(project_root, "output", "data", "01_cleaning")
out_fig_dir <- file.path(project_root, "output", "figures", "01_cleaning")
out_csv <- file.path(out_data_dir, "cleaned_flu_admissions.csv")
out_png <- file.path(out_fig_dir, "epicurve_us_flu_admissions.png")

dir.create(out_data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_fig_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(infile)) stop(paste0("Input file not found: ", infile))

# Read column names first without loading the full data.
header_df <- readr::read_csv(infile, col_types = cols(.default = col_character()), n_max = 0)
all_names <- names(header_df)

preferred_names <- c("Total.Influenza.Admissions", "Total Influenza Admissions")
influenza_col <- intersect(preferred_names, all_names)
if (length(influenza_col) == 0) {
  stop(paste0("No influenza admissions column found. Tried: ", paste(preferred_names, collapse = ", ")))
}
influenza_col <- influenza_col[1]

if (!("Week Ending Date" %in% all_names)) stop("Column 'Week Ending Date' not found")
if (!("Geographic aggregation" %in% all_names)) stop("Column 'Geographic aggregation' not found")

# Read only the required columns as character to avoid parsing warnings.
raw_df <- readr::read_csv(
  infile,
  col_types = cols(.default = col_character()),
  col_select = c("Week Ending Date", "Geographic aggregation", influenza_col)
)

# Filter to US rows.
raw_df_us <- raw_df %>%
  filter(`Geographic aggregation` == "USA")

if (nrow(raw_df_us) == 0) stop("No rows remain after filtering to Geographic aggregation == 'USA'.")

# Create a temporary data frame with explicit parsing.
cleaned <- raw_df_us %>%
  transmute(
    week_raw = `Week Ending Date`,
    location = "US",
    value_raw = .data[[influenza_col]]
  )

# Parse dates and values explicitly.
parsed_dates <- suppressWarnings(lubridate::parse_date_time(cleaned$week_raw, orders = c("mdy", "ymd", "dmy", "Ymd", "mdY", "ymd HMS", "mdY HMS")))
if (any(is.na(parsed_dates))) {
  stop("Unable to parse all values in 'Week Ending Date'.")
}

cleaned <- cleaned %>%
  mutate(
    week = as.Date(parsed_dates),
    value = readr::parse_number(value_raw)
  ) %>%
  select(week, location, value) %>%
  arrange(week)

# Validation checks.
expected_names <- c("week", "location", "value")
if (nrow(cleaned) <= 0) stop("Validation failed: row count must be greater than 0")
if (!identical(names(cleaned), expected_names)) stop(paste0("Validation failed: column names must be exactly: ", paste(expected_names, collapse = ", ")))
if (!all(cleaned$location == "US")) stop("Validation failed: all 'location' values must be 'US'")
if (!inherits(cleaned$week, "Date")) stop("Validation failed: 'week' must be a Date column")
if (!is.numeric(cleaned$value)) stop("Validation failed: 'value' must be numeric")
if (any(is.na(cleaned$value))) stop("Validation failed: 'value' contains NA after parsing")

# Write cleaned CSV.
readr::write_csv(cleaned, out_csv)
if (!file.exists(out_csv)) stop(paste0("Failed to write output CSV: ", out_csv))

# Create epicurve figure using a numeric vector for the bar heights.
old_par <- par(no.readonly = TRUE)
on.exit(par(old_par), add = TRUE)

x_labels <- format(cleaned$week, "%Y-%m-%d")
display_labels <- x_labels

png(filename = out_png, width = 2400, height = 1200, res = 300)
par(mar = c(8.6, 5, 4, 2), mgp = c(3, 0.8, 0))
barplot(
  height = as.numeric(cleaned$value),
  names.arg = display_labels,
  col = "#2c7fb8",
  main = "US Influenza Admissions (epicurve)",
  xlab = "",
  ylab = "Admissions",
  las = 2,
  cex.names = 0.7,
  cex.axis = 0.8,
  cex.lab = 1.0,
  ylim = c(0, max(as.numeric(cleaned$value), na.rm = TRUE) * 1.1)
)
mtext("Week", side = 1, line = 4.0, cex = 1.0)
dev.off()

if (!file.exists(out_png)) stop(paste0("Failed to write epicurve PNG: ", out_png))

cat("Cleaning complete. Cleaned CSV:", out_csv, "\n")
cat("Epicurve PNG:", out_png, "\n")
