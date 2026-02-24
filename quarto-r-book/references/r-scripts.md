# R Script Integration Patterns: Complete Guide

Quarto Books with R use three patterns for organizing code across chapters. Each pattern follows established software engineering principles (DRY, Separation of Concerns, Single Responsibility) to maintain clean, testable, reusable code.

## Why Use External R Scripts?

Organizing code in separate `.R` files instead of embedding everything in `.qmd` files provides several benefits rooted in software engineering principles:

### DRY (Don't Repeat Yourself)
**Problem**: Helper functions for tables, data cleaning logic, or transformation pipelines repeated across multiple chapters.

**Solution**: Define once in `.R` files, use everywhere. Changes propagate automatically.

**Example**: `create_zero_proportion_table()` used in chapters 2, 3, and appendix 10. Defined once in `funciones-tablas.R`, loaded via `.Rprofile`, available everywhere.

### Separation of Concerns
**Problem**: Mixing narrative (analysis, interpretation) with implementation (function definitions, data wrangling) clutters `.qmd` files and reduces readability.

**Solution**:
- `.qmd` files focus on **narrative**: "what" and "why"
- `.R` files contain **implementation**: "how"

**Example**: `chapters/03-data-cleaning.qmd` tells the story of data cleaning decisions. `scripts/data-cleaning.R` contains the pure functions that execute those decisions.

### Single Responsibility Principle
**Problem**: Functions that do too much, or `.qmd` files that handle both presentation and computation.

**Solution**: Each `.R` script has a clear, focused purpose:
- `setup.R` → packages + global options
- `funciones-tablas.R` → table formatting helpers
- `data-cleaning.R` → data quality functions
- `transformations.R` → feature engineering functions

### Testability
**Problem**: Functions embedded in `.qmd` chunks are hard to test in isolation.

**Solution**: Functions in `.R` files can be:
- Tested with `testthat` package
- Sourced in test files without rendering the book
- Documented with roxygen2 (`#' @param`, `#' @return`)

### Reusability
**Problem**: Useful functions trapped in one project's `.qmd` files.

**Solution**: `.R` scripts can be:
- Copied to new projects
- Evolved into R packages
- Shared with collaborators

---

## Pattern 1: .Rprofile for Automatic Global Loading

### What it does

Automatically loads scripts when R starts, making their contents available globally across all `.qmd` files without explicit `source()` or `library()` calls.

### When to use

- Setup code needed in **every** chapter (package loading, global options)
- Helper functions used throughout the book (table formatters, plot themes)
- Configuration that must be consistent project-wide

### How it works

`.Rprofile` in the project root executes automatically when:
- RStudio opens the project
- R starts with working directory set to the project root
- `quarto render` executes

Scripts loaded via `.Rprofile` become part of the global environment for all subsequent R code execution in any `.qmd` file.

### Setup

**`.Rprofile` (project root)**:

```r
# .Rprofile
source("scripts/setup.R")
source("scripts/funciones-tablas.R")
```

**`scripts/setup.R`**:

```r
# scripts/setup.R
# Global packages and configuration for all chapters

# Load packages
library(tidyverse)
library(modeldata)
library(skimr)
library(scales)
library(knitr)

# Resolve namespace conflicts
# When multiple packages export functions with the same name,
# declare which version to use by default
conflicted::conflicts_prefer(
  dplyr::filter,
  dplyr::lag,
  dplyr::select
)

# knitr chunk options
opts_chunk$set(
  fig.width = 8,
  fig.height = 5,
  fig.align = "center",
  comment = "#>",
  collapse = TRUE
)

# ggplot2 theme
theme_set(theme_minimal())
```

**`scripts/funciones-tablas.R`**:

```r
# scripts/funciones-tablas.R
# Helper functions for descriptive tables

#' Create classification table for numeric variables
#'
#' @param dict Dictionary tibble with columns: variable, tipo_semantico, description
#' @param data Data tibble
#' @param vars Optional character vector of variable names to include
#' @return kable table
create_num_classification_table <- function(dict, data, vars = NULL) {
  if (is.null(vars)) {
    vars <- dict %>%
      filter(tipo_semantico %in% c("continua", "discreta")) %>%
      pull(variable)
  }

  dict %>%
    filter(variable %in% vars) %>%
    left_join(
      data %>%
        select(all_of(vars)) %>%
        summarise(across(everything(), n_distinct)) %>%
        pivot_longer(everything(), names_to = "variable", values_to = "cardinalidad"),
      by = "variable"
    ) %>%
    select(variable, description, tipo_semantico, cardinalidad) %>%
    kable()
}

#' Create zero proportion table
#'
#' @param dict Dictionary tibble
#' @param data Data tibble
#' @param top_n Optional number of top variables to show
#' @return kable table
create_zero_proportion_table <- function(dict, data, top_n = NULL) {
  zero_props <- data %>%
    select(where(is.numeric)) %>%
    summarise(across(everything(), ~ mean(. == 0, na.rm = TRUE))) %>%
    pivot_longer(everything(), names_to = "variable", values_to = "prop_zeros") %>%
    arrange(desc(prop_zeros))

  if (!is.null(top_n)) {
    zero_props <- zero_props %>% slice_head(n = top_n)
  }

  zero_props %>%
    left_join(dict, by = "variable") %>%
    mutate(prop_zeros = scales::percent(prop_zeros, accuracy = 0.01)) %>%
    select(variable, prop_zeros, tipo_semantico, description) %>%
    kable()
}
```

### Usage in `.qmd` files

**No setup required**. Functions are instantly available:

```r
#| label: zeros-structural
#| tbl-cap: "Variables with highest proportion of zeros"

# Function available without source() or library()
create_zero_proportion_table(ames_dict, ames_raw, top_n = 15)
```

```r
#| label: num-classification
#| tbl-cap: "Numeric variables classification"

vars <- c("Sale_Price", "Gr_Liv_Area", "Lot_Area", "Garage_Cars")
create_num_classification_table(ames_dict, ames_raw, vars)
```

### Benefits

✅ **Consistency**: Same environment in all chapters
✅ **DRY**: No repeated `library()` or `source()` calls
✅ **Convenience**: Helper functions instantly available
✅ **Single source of truth**: One place to configure packages and options

### Caveats

⚠️ **Restart required**: Changes to `.Rprofile` require restarting R session
⚠️ **Hidden dependencies**: Not obvious from reading `.qmd` what packages/functions are available
⚠️ **Testing complexity**: Functions in `.Rprofile` scripts harder to test in isolation

### When NOT to use

❌ Chapter-specific functions (use Pattern 2 or 3 instead)
❌ One-off utility functions (inline in `.qmd` is fine)
❌ Experimental code (iterate in `.qmd` first, promote to `.Rprofile` when stable)

---

## Pattern 2: knitr::read_chunk() for Labeled Chunks

### What it does

Defines functions in `.R` files with special labels, registers them with `knitr::read_chunk()`, then pulls definitions into `.qmd` files via empty labeled chunks. After loading, functions are invoked normally.

### When to use

- Function definitions you want to **show** in rendered output
- Keeping `.qmd` narrative-focused while preserving function definitions in `.R`
- Reusable code blocks across multiple chapters
- Teaching contexts where showing function source is important

### How it works

Three-step pattern:

1. **Label chunks in .R file**: Use `## ---- label ----` comments
2. **Register in .qmd**: Call `knitr::read_chunk("../scripts/file.R")`
3. **Load + invoke**: Empty chunk with `#| label:` loads definition, then invoke function normally

### Setup in `.R` file

**`scripts/data-cleaning.R`**:

```r
# scripts/data-cleaning.R
# Pure functions for data cleaning with attribute-based tracing

## ---- convert-structural-zeros ----
#' Convert structural zeros to NA
#'
#' @description
#'   Detects numeric variables using 0 as structural absence and converts
#'   those zeros to NA. Records how many conversions per variable.
#'
#' @param data Tibble or data.frame
#' @param zero_vars Character vector of variable names; if NULL, auto-detects
#'   all numeric variables containing at least one 0
#' @param verbose Logical; if TRUE, prints conversion summary and returns list
#'
#' @return
#'   - If verbose = FALSE: tibble with zeros converted to NA, with attribute
#'     "zero_summary" (tibble with columns variable and n_converted)
#'   - If verbose = TRUE: list with elements data (tibble) and summary (tibble)
#'
#' @export
convert_structural_zeros_to_na <- function(data, zero_vars = NULL, verbose = FALSE) {
  stopifnot(is.data.frame(data), is.null(zero_vars) || is.character(zero_vars), is.logical(verbose))

  # Auto-detect if not provided
  if (is.null(zero_vars)) {
    zero_vars <- data %>%
      select(where(is.numeric)) %>%
      summarise(across(everything(), ~ any(. == 0, na.rm = TRUE))) %>%
      pivot_longer(everything(), names_to = "variable", values_to = "has_zero") %>%
      filter(has_zero) %>%
      pull(variable)
  }

  conversion_log <- tibble(variable = character(), n_converted = integer())

  for (var in zero_vars) {
    n0 <- sum(data[[var]] == 0, na.rm = TRUE)
    if (verbose && n0 > 0) {
      message(sprintf("  %s: converting %d zeros to NA", var, n0))
    }
    conversion_log <- conversion_log %>% add_row(variable = var, n_converted = n0)
  }

  # Convert zeros to NA
  data_out <- data %>%
    mutate(across(all_of(zero_vars), ~ ifelse(. == 0, NA_real_, .)))

  # Attach metadata
  attr(data_out, "zero_summary") <- conversion_log

  if (verbose) {
    return(list(data = data_out, summary = conversion_log))
  }
  data_out
}

## ---- create-has-indicators ----
#' Create binary has_* indicators from categorical variables
#'
#' @param data Tibble or data.frame
#' @param cat_vars Character vector of categorical variable names
#' @param none_levels Character vector of levels indicating absence
#'   (e.g., "None", "No_Garage", "No_Basement")
#'
#' @return Tibble with new has_* columns (0/1 integer)
#'
#' @export
create_has_indicators <- function(data, cat_vars, none_levels, verbose = FALSE) {
  stopifnot(is.data.frame(data), is.character(cat_vars), is.character(none_levels))

  has_log <- tibble(variable = character(), has_name = character(), n_present = integer())

  for (var in cat_vars) {
    if (!var %in% names(data)) next

    has_name <- paste0("has_", tolower(gsub("_", "", var)))
    data <- data %>%
      mutate(!!has_name := as.integer(!.data[[var]] %in% none_levels))

    n_present <- sum(data[[has_name]], na.rm = TRUE)
    has_log <- has_log %>% add_row(variable = var, has_name = has_name, n_present = n_present)
  }

  attr(data, "has_summary") <- has_log

  if (verbose) {
    return(list(data = data, summary = has_log))
  }
  data
}

## ---- recode-categorical-absence ----
#' Recode discordant categorical-numeric pairs
#'
#' @param data Tibble or data.frame
#' @param pairs List of character vectors, each c(cat_var, num_var)
#' @param none_levels Character vector of absence levels
#'
#' @return Tibble with recoded categorical variables
#'
#' @export
recode_categorical_absence <- function(data, pairs, none_levels) {
  recode_log <- tibble(pair = character(), cat_var = character(), num_var = character(),
                       none_but_positive = integer(), present_but_zero = integer())

  for (pair in pairs) {
    cat_var <- pair[1]
    num_var <- pair[2]

    if (!all(c(cat_var, num_var) %in% names(data))) next

    # Count discrepancies
    none_but_pos <- data %>%
      filter(.data[[cat_var]] %in% none_levels, .data[[num_var]] > 0, !is.na(.data[[num_var]])) %>%
      nrow()

    present_but_zero <- data %>%
      filter(!.data[[cat_var]] %in% none_levels, .data[[num_var]] == 0, !is.na(.data[[cat_var]])) %>%
      nrow()

    # Recode: if cat = None but num > 0, change cat to "Other"
    if (none_but_pos > 0) {
      data <- data %>%
        mutate(!!cat_var := ifelse(.data[[cat_var]] %in% none_levels & .data[[num_var]] > 0,
                                    "Other", as.character(.data[[cat_var]])))
    }

    # Recode: if cat != None but num = 0, change num to NA
    if (present_but_zero > 0) {
      data <- data %>%
        mutate(!!num_var := ifelse(!.data[[cat_var]] %in% none_levels & .data[[num_var]] == 0,
                                    NA_real_, .data[[num_var]]))
    }

    recode_log <- recode_log %>%
      add_row(pair = paste(cat_var, num_var, sep = " + "),
              cat_var = cat_var, num_var = num_var,
              none_but_positive = none_but_pos,
              present_but_zero = present_but_zero)
  }

  attr(data, "recode_summary") <- recode_log
  data
}
```

### Usage in `.qmd` file

**`chapters/03-data-cleaning.qmd`**:

**Step 1: Register chunks** (do this once at the top of the chapter):

```r
#| label: register-clean
#| cache: FALSE
knitr::read_chunk("../scripts/data-cleaning.R")
```

**Step 2: Load function definitions** (empty chunks pull code from .R):

```r
#| label: convert-structural-zeros
# This chunk is EMPTY — definition comes from data-cleaning.R
```

```r
#| label: create-has-indicators
# This chunk is EMPTY — definition comes from data-cleaning.R
```

```r
#| label: recode-categorical-absence
# This chunk is EMPTY — definition comes from data-cleaning.R
```

**Step 3: Invoke the functions**:

```r
#| label: structural-zero-clean
#| tbl-cap: "Summary of zero-to-NA conversions"

structural_zero_vars <- c(
  "Pool_Area", "Three_season_porch", "Misc_Val", "Bsmt_Half_Bath",
  "Screen_Porch", "BsmtFin_SF_2", "Enclosed_Porch", "Mas_Vnr_Area",
  "Bsmt_Full_Bath", "Wood_Deck_SF", "Garage_Area", "Garage_Cars", "Lot_Frontage"
)

# Function is now available because we loaded its definition above
ames1 <- convert_structural_zeros_to_na(ames_raw, zero_vars = structural_zero_vars)

# Access metadata attached by the function
attr(ames1, "zero_summary") %>% knitr::kable()
```

```r
#| label: add-has-indicators
#| tbl-cap: "Summary of has_* indicators created"

cat_vars <- c("Pool_QC", "Mas_Vnr_Type", "Garage_Cond", "Bsmt_Cond", "Fence", "Alley")
none_levels <- c("None", "No_Alley_Access", "No_Pool", "No_Fence", "No_Garage", "No_Basement")

ames_clean <- create_has_indicators(ames1, cat_vars, none_levels)

attr(ames_clean, "has_summary") %>% knitr::kable()
```

### Pattern summary

1. **Register**: `knitr::read_chunk("../scripts/data-cleaning.R")` once per chapter
2. **Load**: Empty chunks with `#| label: function-name` (one per function)
3. **Invoke**: Call functions normally: `result <- function_name(...)`

### Benefits

✅ **Separation of concerns**: Logic in `.R`, narrative in `.qmd`
✅ **Show source**: Function definitions appear in rendered book if desired
✅ **Reusable**: Same chunk can be referenced in multiple chapters
✅ **Version control**: Easier to track changes in `.R` files
✅ **Testing**: Functions in `.R` files are easier to test independently

### Caveats

⚠️ **Cache sensitivity**: Use `cache: FALSE` on the registration chunk
⚠️ **Label matching**: Chunk labels must match exactly between `.R` and `.qmd`
⚠️ **Not automatic**: Empty chunks required for each function you want to load
⚠️ **Two-step process**: Load definition, then invoke (beginners may find confusing)

### Control visibility

Show function definition in output:

```r
#| label: convert-structural-zeros
#| echo: true
# Empty chunk with echo=true shows the function source
```

Hide function definition (only show results when invoked):

```r
#| label: convert-structural-zeros
#| echo: false
# Or use include: false to suppress entirely
```

---

## Pattern 3: Direct source() for Function Libraries

### What it does

Loads all functions from a `.R` file into the current environment with a single `source()` call, making them immediately available for use.

### When to use

- Collection of utility functions that don't need to be visible in output
- Transformation pipelines with multiple related functions
- When you want simple, straightforward loading without chunk management
- Production code where showing source isn't necessary

### How it works

`source("path/to/file.R")` reads and executes the entire `.R` file. All function definitions become available in the current environment.

### Setup in `.R` file

**`scripts/transformations.R`**:

```r
# scripts/transformations.R
# Pure functions for data transformations
# All functions are self-contained and follow a consistent pattern:
# - Take data as first argument
# - Return transformed data
# - Attach metadata as attributes for traceability

drop_outliers_grlivarea <- function(data, cutoff = 4000, col = "Gr_Liv_Area") {
  stopifnot(col %in% names(data))

  n_before <- nrow(data)
  data_out <- data %>%
    filter(.data[[col]] <= cutoff | is.na(.data[[col]]))
  n_dropped <- n_before - nrow(data_out)

  attr(data_out, "dropped_grlivarea_rows") <- n_dropped
  data_out
}

subset_for_intro <- function(data,
                             sale_condition_col = "Sale_Condition",
                             keep_normal = TRUE,
                             max_area = 1500,
                             area_col = "Gr_Liv_Area") {
  data_out <- data

  if (keep_normal && sale_condition_col %in% names(data_out)) {
    data_out <- data_out %>%
      filter(.data[[sale_condition_col]] == "Normal")
  }

  if (!is.null(max_area) && area_col %in% names(data_out)) {
    data_out <- data_out %>%
      filter(.data[[area_col]] <= max_area | is.na(.data[[area_col]]))
  }

  data_out
}

create_total_sqft <- function(data,
                              bsmt_col = "Total_Bsmt_SF",
                              living_col = "Gr_Liv_Area",
                              new_col = "Total_SqFt") {
  data %>%
    mutate(!!new_col := .data[[bsmt_col]] + .data[[living_col]])
}

create_fireyn <- function(data, fireplace_col = "Fireplaces", new_col = "FireYN") {
  data %>%
    mutate(!!new_col := factor(ifelse(.data[[fireplace_col]] > 0, "Y", "N")))
}

collapse_ordinal_scales <- function(data) {
  data %>%
    mutate(
      Bsmt_Cond_grp = fct_collapse(Bsmt_Cond,
                                    Good = c("Excellent", "Good"),
                                    Fair = c("Typical"),
                                    Poor = c("Fair", "Poor")),
      Garage_Cond_grp = fct_collapse(Garage_Cond,
                                      Good = c("Excellent", "Good"),
                                      Fair = c("Typical"),
                                      Poor = c("Fair", "Poor"))
    )
}

reorder_factor_baselines <- function(data) {
  data %>%
    mutate(
      MS_Zoning = fct_relevel(MS_Zoning, "Residential_Low_Density"),
      Street = fct_relevel(Street, "Paved"),
      Lot_Shape = fct_relevel(Lot_Shape, "Regular")
    )
}

apply_power_transformations <- function(data, vars, power = "log") {
  stopifnot(power %in% c("log", "sqrt", "square"))

  transform_suffix <- switch(power,
                            log = "_log",
                            sqrt = "_sqrt",
                            square = "_sq")

  for (var in vars) {
    if (!var %in% names(data)) next

    new_var <- paste0(var, transform_suffix)

    data <- data %>%
      mutate(!!new_var := switch(power,
                                 log = log(.data[[var]] + 1),
                                 sqrt = sqrt(.data[[var]]),
                                 square = .data[[var]]^2))
  }

  attr(data, "transform_log") <- list(
    power = power,
    variables = vars,
    suffix = transform_suffix
  )

  data
}
```

### Usage in `.qmd` file

**`chapters/04-transformations.qmd`**:

**Load the entire library**:

```r
#| label: load-transformations
source("../scripts/transformations.R")
```

**Use functions immediately**:

```r
#| label: apply-transformations

# All functions from transformations.R are now available

# Step 1: Remove outliers (De Cock recommendation)
ames_tf <- drop_outliers_grlivarea(ames_clean, cutoff = 4000)

# Check metadata
attr(ames_tf, "dropped_grlivarea_rows")  # 4 rows

# Step 2: Create derived variables
ames_tf <- create_total_sqft(ames_tf)
ames_tf <- create_fireyn(ames_tf)

# Step 3: Collapse ordinal scales
ames_tf <- collapse_ordinal_scales(ames_tf)

# Step 4: Reorder factor baselines for modeling
ames_tf <- reorder_factor_baselines(ames_tf)

# Step 5: Apply power transformations
numeric_vars <- c("Sale_Price", "Gr_Liv_Area", "Lot_Area", "Total_SqFt")
ames_tf <- apply_power_transformations(ames_tf, vars = numeric_vars, power = "log")

# Check transformation log
attr(ames_tf, "transform_log")
```

### Benefits

✅ **Simple**: One call loads everything
✅ **Fast**: No chunk management overhead
✅ **Clean**: Functions don't clutter rendered output
✅ **Flexible**: Can source multiple files if needed

### Caveats

⚠️ **All or nothing**: Can't selectively load individual functions
⚠️ **Hidden in output**: Function definitions not visible unless you explicitly show them
⚠️ **Namespace pollution**: All functions enter the environment (usually not a problem)

### When NOT to use

❌ Teaching contexts where showing function source is important (use Pattern 2)
❌ When you need fine-grained control over which functions to load (use Pattern 2)
❌ When functions are better suited for a package (create a package instead)

---

## Choosing the Right Pattern

| Pattern | Use when... | Visibility | Scope |
|---------|------------|------------|-------|
| **1: .Rprofile** | Functions needed in **all** chapters | Hidden (auto-loaded) | Global |
| **2: read_chunk()** | Want to **show** function source in output | Visible (if echo=true) | Per-chapter |
| **3: source()** | Just need functions **available**, not visible | Hidden (explicit load) | Per-chapter |

### Decision tree

```
Do you need this in ALL chapters?
├─ YES → Use Pattern 1 (.Rprofile)
└─ NO → Do you want to show the function source in rendered output?
    ├─ YES → Use Pattern 2 (read_chunk)
    └─ NO → Use Pattern 3 (source)
```

### Real project example

From the Ames Housing project:

- **Pattern 1** (`.Rprofile`):
  - `scripts/setup.R` — tidyverse, conflicted, knitr options
  - `scripts/funciones-tablas.R` — 8 helper functions for tables

- **Pattern 2** (`read_chunk`):
  - `scripts/data-cleaning.R` — 4 functions shown in Chapter 3

- **Pattern 3** (`source`):
  - `scripts/transformations.R` — 7 functions used in Chapter 4

---

## Path Conventions

### From chapter files

When your `.qmd` is in `chapters/`:

```r
# Data
ames_clean <- readRDS("../data/ames_clean.rds")

# Scripts
source("../scripts/transformations.R")
knitr::read_chunk("../scripts/data-cleaning.R")

# Images
knitr::include_graphics("../images/diagram.png")
```

### From root files

When your `.qmd` is in project root (`index.qmd`):

```r
# Data
ames_clean <- readRDS("data/ames_clean.rds")

# Scripts
source("scripts/transformations.R")
```

### Never use absolute paths

❌ Bad:
```r
source("/Users/username/projects/ames-housing/scripts/file.R")
```

✅ Good:
```r
source("../scripts/file.R")  # from chapters/
source("scripts/file.R")     # from root
```

Absolute paths break when:
- Project moves to different location
- Another user clones the repository
- Project runs on CI/CD

---

## Common Issues and Solutions

### Issue: .Rprofile changes not taking effect

**Cause**: R session started before `.Rprofile` was modified, or session hasn't restarted since changes.

**Solution**: Restart R session:
- RStudio: Session → Restart R (Ctrl/Cmd + Shift + F10)
- Command line: quit and restart R

### Issue: Functions from .Rprofile scripts not available

**Cause**: `.Rprofile` doesn't have correct `source()` calls, or script path is wrong.

**Solution**:
1. Check `.Rprofile` contains: `source("scripts/filename.R")`
2. Verify script exists at that path
3. Restart R session

### Issue: read_chunk() labels not found

**Cause**: Chunk labels in `.R` file don't match labels in `.qmd`, or registration chunk has cache enabled.

**Solution**:
1. Verify label format in `.R`: `## ---- exact-label ----`
2. Verify label in `.qmd`: `#| label: exact-label`
3. Use `cache: FALSE` on the registration chunk
4. Clear render cache: delete `_book/` and re-render

### Issue: "Object not found" after read_chunk()

**Cause**: Loaded the definition with empty chunk but forgot to invoke the function.

**Solution**: Empty chunk only loads the definition. You must still call the function:

```r
#| label: my-function
# Loads definition (empty chunk)
```

```r
#| label: use-my-function
# Now invoke it
result <- my_function(data)
```

### Issue: Function definition appears twice in output

**Cause**: Using both `read_chunk()` empty chunk AND explicit function definition in the `.qmd`.

**Solution**: Choose one pattern. Don't mix:

❌ Bad (duplicated):
```r
#| label: my-function
# Empty chunk loads from .R
```

```r
# Also defined explicitly in .qmd
my_function <- function(data) { ... }
```

✅ Good (pick one):
```r
# Option A: read_chunk
#| label: my-function
```

OR

```r
# Option B: inline definition
my_function <- function(data) { ... }
```

### Issue: source() fails with "cannot open file"

**Cause**: Incorrect relative path from current `.qmd` location.

**Solution**: Check working directory context:
- From `chapters/*.qmd`: use `../scripts/`
- From `index.qmd`: use `scripts/`
- Test path: `file.exists("../scripts/file.R")`

### Issue: Data paths broken from chapters/

**Cause**: Forgot that paths are relative to current file, not project root.

**Solution**: From `chapters/*.qmd`, always use `../`:
```r
ames_clean <- readRDS("../data/ames_clean.rds")
```

### Issue: Changes in sourced .R files not reflected

**Cause**: knitr cache is stale.

**Solution**:
1. Delete `_book/` directory
2. Re-render with `quarto render`
3. Or set `cache: FALSE` on chunks using those functions
