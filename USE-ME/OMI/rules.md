# Data Cleaning Rules

These rules define how the agent should generate `output/scripts/01_cleaning.R`. Follow each
step in order. The goal is to turn the raw NHSN HRD influenza file into a tidy,
three-column dataset ready for downstream modeling and produce an epicurve
figure.

## 1. Load the data

Read the NHSN HRD CSV from the `data/` folder using **readr** (`read_csv()`).
To avoid parsing warnings from unrelated fields, import only required columns:

- `Week Ending Date`
- `Geographic aggregation`
- Influenza admissions column (see Rule 3)

Import these columns as character first, then parse/convert explicitly.

## 2. Filter to US only

Use the `Geographic aggregation` column. Keep only the rows where the value is
`"USA"`.

## 3. Select the target column

Use influenza admissions from one of these allowed column names:

- `Total.Influenza.Admissions`
- `Total Influenza Admissions`

Fail with a clear error if neither exists.

## 4. Reshape to three columns

Rename and restructure the data to exactly three columns:

- `week`
- `location` — set to `"US"`
- `value`

Convert `value` with `readr::parse_number()` so values like `1,110` are valid.
Do not use `parse_double()` directly on comma-formatted counts.

## 5. Format dates

Convert `Week Ending Date` to an R `Date` object in `week`. Sort ascending by
`week`.

## 6. Save the output

Write the cleaned data to `cleaned_flu_admissions.csv` in the `output/data/01_cleaning` folder.

## 7. Generate epicurve figure

Create an epicurve from the cleaned data and save to:

- `output/figures/01_cleaning/epicurve_us_flu_admissions.png`

Plot requirements:

- X-axis: `week`
- Y-axis: `value`
- Ensure plotting input is a numeric vector (for example `as.numeric(value)`) so
	`barplot()` does not fail with height-type errors.
- Keep all weekly dates visible on the x-axis (do not downsample labels).
- Prevent overlap between x-axis date labels and the x-axis title by explicitly
	adding spacing between date labels and the `Week` label.
- Preserve this spacing behavior in future edits unless a new rule explicitly
	changes it.

## 8. Required validation checks

The script must include checks that stop execution on failure:

- Row count is greater than 0
- Column names are exactly `week`, `location`, `value` in that order
- `location` is always `"US"`
- `week` inherits class `Date`
- `value` is numeric
- `value` has no `NA` values after parsing
- Output CSV exists at `output/data/01_cleaning/cleaned_flu_admissions.csv`
- Epicurve file exists at `output/figures/01_cleaning/epicurve_us_flu_admissions.png`




# Visualization

These rules define how the agent should generate `output/scripts/02_data_explore.R`. 

## Season Definition

When mapping calendar dates to MMWR epi-weeks, handle week numbers that fall in early January (for example epi-week 53) by using the calendar month to assign the season start year. Concretely, if a date's epiweek is >= 40 but its calendar month is January–August, attribute that date to the previous year's season (i.e., season_start_year = year - 1).

### National Plot

- Plot all hospitalization from the `cleaned_flu_admissions.csv`
- data range: August 8 2020 through June 20 2026
- title: All US Influenza hospitalization
- plot type: bar plot
- color: green
- x-axis label: Week
- y-axis label: Hospitalization
- shade the most recent season
- output this plot with the output > figure
