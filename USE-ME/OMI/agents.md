# Agent Instructions

Purpose
- Create a reproducible R script at `output/scripts/01_cleaning.R` that implements the workflow described in `rules.md`.
- The script must transform the raw NHSN HRD influenza CSV into a tidy, three-column dataset and produce the required figure outputs.

## Source of truth
- `rules.md` is the specification.
- If a rule is ambiguous, follow the rule exactly and do not invent extra behavior.

## Required workflow
1. Load the data
   - Read the CSV from `data/Weekly Hospital Respiratory Data (HRD) Metrics by Jurisdiction.csv`.
   - Use `readr::read_csv()`.
   - Import only the required columns initially:
     - `Week Ending Date`
     - `Geographic aggregation`
     - Influenza admissions column (one of `Total.Influenza.Admissions` or `Total Influenza Admissions`)
   - Import these as character first, then convert explicitly.

2. Filter to US only
   - Keep only rows where `Geographic aggregation` equals `"USA"`.

3. Select influenza admissions column
   - Accept only `Total.Influenza.Admissions` or `Total Influenza Admissions`.
   - If neither exists, stop with a clear error.

4. Reshape to three columns
   - Produce exactly these columns, in this order:
     - `week`
     - `location`
     - `value`
   - Set `location` to the literal `"US"` for all rows.
   - Parse `value` with `readr::parse_number()` so comma-formatted counts are handled correctly.

5. Format dates
   - Convert `Week Ending Date` to an R `Date` object in `week`.
   - Sort rows ascending by `week`.

6. Save cleaned data
   - Write the cleaned dataset to `output/data/01_cleaning/cleaned_flu_admissions.csv`.

7. Create epicurve figure
   - Create an epicurve plot and save it to `output/figures/01_cleaning/epicurve_us_flu_admissions.png`.
   - Plot requirements:
     - X-axis: `week`
     - Y-axis: `value`
     - Ensure plotting input is numeric (for example `as.numeric(value)`) so `barplot()` does not fail.
       - Keep all weekly dates visible on the x-axis (do not downsample labels).
       - Prevent overlap between x-axis date labels and the x-axis title by explicitly adding spacing between date labels and the `Week` label.
       - Preserve this spacing behavior in future edits unless a new rule explicitly changes it.

## Required validation checks
The script must stop execution on failure if any of the following checks fail:
- Row count is greater than 0
- Column names are exactly `week`, `location`, `value` in that order
- `location` is always `"US"`
- `week` inherits class `Date`
- `value` is numeric
- `value` has no `NA` values after parsing
- Output CSV exists at `output/data/01_cleaning/cleaned_flu_admissions.csv`
- Epicurve file exists at `output/figures/01_cleaning/epicurve_us_flu_admissions.png`

## Implementation notes
- Create output directories before writing files.
- Use explicit conversions for date and numeric data.
- Write clear error messages when required columns are missing or parsing fails.
- Keep the script self-contained and reproducible.

## Visualization workflow (`output/scripts/02_data_explore.R`)
- Read input from `output/data/01_cleaning/cleaned_flu_admissions.csv`.
- Use the season mapping rule when handling early-January epi-weeks:
   - If `epiweek >= 40` and calendar month is January-August, assign that row to
      the previous season start year (`season_start_year = year - 1`).

### National plot requirements
- Plot all hospitalizations from `cleaned_flu_admissions.csv` for the date range
   `2020-08-08` through `2026-06-20`.
- Title: `All US Influenza hospitalization`.
- Plot type: bar plot.
- Color: green.
- X-axis label: `Week`.
- Y-axis label: `Hospitalization`.
- Shade the most recent season.
- Save output figure under `output/figures/`.
