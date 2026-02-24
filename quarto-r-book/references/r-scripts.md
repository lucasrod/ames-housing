# R Script Integration: Complete Guide

Three patterns for organizing R code across Quarto Book chapters, each with clear use cases based on software engineering principles.

## Why Use External R Scripts?

**DRY (Don't Repeat Yourself)**: Define helper functions once, use everywhere. Example: `create_zero_proportion_table()` used in chapters 2, 3, and appendix 10.

**Separation of Concerns**: `.qmd` files focus on narrative (what/why), `.R` files contain implementation (how).

**Testability**: Functions in `.R` files can be tested with `testthat`, documented with roxygen2, and sourced independently.

---

## Pattern 1: .Rprofile (Automatic Global)

**When**: Functions/packages needed in **all** chapters.

**Setup** (`.Rprofile` in project root):
```r
source("scripts/setup.R")
source("scripts/funciones-tablas.R")
```

**Example `scripts/setup.R`**:
```r
library(tidyverse)
library(modeldata)
library(skimr)

conflicted::conflicts_prefer(dplyr::filter, dplyr::lag)

opts_chunk$set(fig.width = 8, fig.height = 5)
```

**Usage in any `.qmd`** (no setup needed):
```r
create_zero_proportion_table(ames_dict, ames_raw, top_n = 15)
```

**Caveat**: Restart R session after changes.

---

## Pattern 2: read_chunk() (Show Source)

**When**: Function definitions you want visible in rendered output.

**Setup in `.R`** (`scripts/data-cleaning.R`):
```r
## ---- convert-structural-zeros ----
convert_structural_zeros_to_na <- function(data, zero_vars, verbose = FALSE) {
  # ... implementation ...
  data_out
}

## ---- create-has-indicators ----
create_has_indicators <- function(data, cat_vars, none_levels) {
  # ... implementation ...
  data_out
}
```

**Usage in `.qmd`** (3 steps):

**1. Register**:
```r
#| label: register-clean
#| cache: FALSE
knitr::read_chunk("../scripts/data-cleaning.R")
```

**2. Load definitions** (empty chunks):
```r
#| label: convert-structural-zeros
```

```r
#| label: create-has-indicators
```

**3. Invoke**:
```r
structural_zero_vars <- c("Pool_Area", "Garage_Area", "Mas_Vnr_Area")
ames1 <- convert_structural_zeros_to_na(ames_raw, zero_vars = structural_zero_vars)

cat_vars <- c("Pool_QC", "Mas_Vnr_Type", "Garage_Cond")
ames_clean <- create_has_indicators(ames1, cat_vars, none_levels)
```

---

## Pattern 3: source() (Hide Source)

**When**: Functions available but not visible in output.

**Setup in `.R`** (`scripts/transformations.R`):
```r
drop_outliers_grlivarea <- function(data, cutoff = 4000) {
  data %>% filter(Gr_Liv_Area <= cutoff | is.na(Gr_Liv_Area))
}

create_total_sqft <- function(data) {
  data %>% mutate(Total_SqFt = Total_Bsmt_SF + Gr_Liv_Area)
}
```

**Usage in `.qmd`**:
```r
#| label: load-transformations
source("../scripts/transformations.R")
```

```r
ames_tf <- drop_outliers_grlivarea(ames_clean, cutoff = 4000)
ames_tf <- create_total_sqft(ames_tf)
```

---

## Decision Tree

```
Need in ALL chapters?
├─ YES → Pattern 1 (.Rprofile)
└─ NO → Show function source in output?
    ├─ YES → Pattern 2 (read_chunk)
    └─ NO  → Pattern 3 (source)
```

---

## Path Conventions

From `chapters/*.qmd`:
```r
source("../scripts/file.R")
read_rds("../data/file.rds")
```

From `index.qmd`:
```r
source("scripts/file.R")
read_rds("data/file.rds")
```

Never absolute paths.

---

## Common Issues

| Issue | Fix |
|-------|-----|
| `.Rprofile` not loading | Must be in project root. Restart R session. |
| `read_chunk()` labels not found | Use `cache: FALSE` on registration chunk. Check labels match exactly. |
| "Object not found" after `read_chunk()` | Empty chunk loads definition. Must invoke in separate chunk. |
| `source()` path not found | From `chapters/`: use `../scripts/` |
| Changes not reflected | Clear knitr cache: delete `_book/`, re-render |

---

## Real Project Examples

### Ames Housing Structure

**Pattern 1** (`.Rprofile` loads):
- `scripts/setup.R` → tidyverse, knitr options
- `scripts/funciones-tablas.R` → 8 table helpers

**Pattern 2** (`read_chunk` in cap. 3):
- `scripts/data-cleaning.R` → 4 functions with roxygen docs

**Pattern 3** (`source` in cap. 4):
- `scripts/transformations.R` → 7 transformation functions

### Function Pattern (from project)

All functions follow:
- **Pure**: input data.frame → output data.frame
- **Traceable**: attach metadata as attributes (`attr(data, "zero_summary")`)
- **Validated**: `stopifnot()` preconditions
- **Documented**: roxygen2 (`#' @param`, `#' @return`)
- **Verbose option**: return list with summary or just data

Example:
```r
convert_structural_zeros_to_na <- function(data, zero_vars, verbose = FALSE) {
  stopifnot(is.data.frame(data))

  # ... transform data ...

  attr(data_out, "zero_summary") <- conversion_log

  if (verbose) {
    return(list(data = data_out, summary = conversion_log))
  }
  data_out
}
```

Access metadata:
```r
ames1 <- convert_structural_zeros_to_na(ames_raw, zero_vars)
attr(ames1, "zero_summary") %>% knitr::kable()
```
