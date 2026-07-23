#!/usr/bin/env Rscript

# 02_data_explore.R
# Reads cleaned flu admissions and creates a national bar plot with the most
# recent season shaded.

pkgs <- c("readr", "dplyr", "lubridate", "ggplot2", "MMWRweek")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org")
  }
}

library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)
library(MMWRweek)

# Resolve project root from this script path.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grepl("^--file=", args)]
if (length(script_arg) > 0) {
  script_path <- sub("^--file=", "", script_arg[1])
} else {
  script_path <- "output/scripts/02_data_explore.R"
}
script_path <- normalizePath(script_path, winslash = "/", mustWork = FALSE)
script_dir <- dirname(script_path)
project_root <- if (basename(script_dir) == "scripts") dirname(dirname(script_dir)) else script_dir

in_csv <- file.path(project_root, "output", "data", "01_cleaning", "cleaned_flu_admissions.csv")
out_png <- file.path(project_root, "output", "figures", "02_data_explore", "national_plot.png")

dir.create(dirname(out_png), recursive = TRUE, showWarnings = FALSE)

if (!file.exists(in_csv)) stop(paste0("Missing input file: ", in_csv))

# Read as character first, then parse explicitly.
df <- readr::read_csv(in_csv, col_types = cols(.default = col_character()))

if (!all(c("week", "location", "value") %in% names(df))) {
  stop("Input must contain columns: week, location, value")
}

df <- df %>%
  transmute(
    week = as.Date(week),
    location = location,
    value = readr::parse_number(value)
  )

if (any(is.na(df$week))) stop("The week could not be parsed.")
if (any(is.na(df$value))) stop("The value could not be parsed.")
if (!all(df$location == "US")) stop("location must be all 'US'.")

# Required date window from rules.
start_date <- as.Date("2020-08-08")
end_date <- as.Date("2026-06-20")

plot_df <- df %>%
  filter(week >= start_date, week <= end_date) %>%
  arrange(week)

if (nrow(plot_df) == 0) stop("No data found in requested range 2020-08-08 to 2026-06-20.")

# Season mapping rule:
# If epiweek >= 40 and month is Jan-Aug, assign to previous season year.
mm <- MMWRweek(plot_df$week)
plot_df <- plot_df %>%
  mutate(
    epiweek = mm$MMWRweek,
    cal_year = year(week),
    cal_month = month(week),
    season_start_year = case_when(
      epiweek >= 40 & cal_month >= 1 & cal_month <= 8 ~ cal_year - 1,
      epiweek >= 40 ~ cal_year,
      epiweek <= 20 ~ cal_year - 1,
      TRUE ~ NA_integer_
    )
  )

season_rows <- plot_df %>% filter(!is.na(season_start_year))
if (nrow(season_rows) == 0) stop("Could not determine season assignments.")

most_recent_start <- max(season_rows$season_start_year, na.rm = TRUE)
recent_season_df <- season_rows %>% filter(season_start_year == most_recent_start)
season_xmin <- min(recent_season_df$week)
season_xmax <- max(recent_season_df$week)

p <- ggplot(plot_df, aes(x = week, y = value)) +
  annotate(
    "rect",
    xmin = season_xmin,
    xmax = season_xmax,
    ymin = -Inf,
    ymax = Inf,
    fill = "grey75",
    alpha = 0.35
  ) +
  geom_col(fill = "green") +
  labs(
    title = "All US Influenza hospitalization",
    x = "Week",
    y = "Hospitalization"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)
  )

ggsave(out_png, plot = p, width = 12, height = 6, dpi = 300)

if (!file.exists(out_png)) stop(paste0("Failed to write figure: ", out_png))

cat("Done. Wrote figure:", out_png, "\n")
