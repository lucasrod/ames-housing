---
name: quarto-r-book
description: Create and manage Quarto Book projects with R. Use when the user wants to set up a new Quarto Book, add chapters/appendices, configure cross-references between .qmd files, embed tables/figures from one chapter into another, set up bibliography/citations, configure R script loading (.Rprofile, knitr::read_chunk, source), or troubleshoot Quarto rendering issues. Covers _quarto.yml configuration, the embed shortcode system, the @ref numbering system, callout blocks, code chunk options, and multi-chapter R workflows.
---

# Quarto R Book

## Overview

Build multi-chapter academic reports and books using Quarto's `book` project type with R. This skill covers project structure, the two cross-referencing systems, R integration, bibliography, and the DRY table management pattern.

## Project Scaffold

Minimal `_quarto.yml` for a book:

```yaml
project:
  type: book

book:
  title: "Book Title"
  subtitle: "Subtitle"
  author:
    - Author Name
  date: "2025-01-01"
  output-file: "output-filename"
  chapters:
    - index.qmd
    - chapters/01-introduction.qmd
    - chapters/02-chapter-name.qmd
  appendices:
    - chapters/09-appendix-a.qmd
    - chapters/10-appendix-b.qmd
    - chapters/references.qmd

bibliography: references.bib
csl: csl/chicago-fullnote-with-ibid.csl
citation-location: margin  # or "document"

crossref:
  fig-title: "Figura"    # heading prefix
  fig-prefix: "figura"   # inline prefix
  tbl-title: "Tabla"
  tbl-prefix: "tabla"
  title-delim: ":"

format:
  html:
    toc: true
    toc-depth: 3
    code-fold: true
    code-tools: true
    code-summary: "Show code"
    theme: cosmo

execute:
  echo: true
  warning: true
  message: false
```

Key points:
- `chapters:` defines numbered body content; `appendices:` adds lettered sections
- `index.qmd` must be first in `chapters:` (it's the landing page)
- `references.qmd` should be the last appendix (contains `::: {#refs} :::`)
- All `.qmd` files in subdirectories must use relative paths for `source()` and data loading

## Two Cross-Referencing Systems

Quarto Book has two distinct systems. See `references/cross-references.md` for the complete guide with examples.

### System A: Embed Shortcode

Renders a chunk's output from another file inline:

```markdown
{{< embed 10-tbl-appendix.qmd#tbl-metrics-global echo=TRUE >}}
```

**When to use**: showing a table/figure that's defined in an appendix or another chapter, without duplicating the code.

**Critical path rule**: paths are relative to the **current file**, not the project root. From `chapters/02-*.qmd`, reference siblings by filename only (no `chapters/` prefix).

### System B: Inline References

Auto-numbered references to labeled chunks:

```markdown
As shown in @tbl-metrics-global, the dataset has 2930 observations.
```

**Requirements**: the target chunk needs both `#| label: tbl-xxx` AND `#| tbl-cap: "Caption"`.

**When to use**: referencing any labeled table, figure, equation, or section by number.

### When to use which

| Goal | System |
|------|--------|
| Display a table/figure from another file | Embed `{{< embed >}}` |
| Reference by number ("see Tabla 2.1") | Inline `@tbl-label` |
| Both display and reference | Embed + `@tbl-label` in text |
| Link to a section | `@sec-id` or `[text](file.qmd#anchor)` |

## Table Management Strategy (DRY)

Tables with >12-15 rows belong in appendix `.qmd` files. In main chapters, show only a preview inline, then embed the full version from the appendix.

**Pattern**:

1. **Appendix** (`tbl-appendix.qmd`): full table with `#| label: tbl-foo` + `#| tbl-cap:`
2. **Main chapter**: inline preview with its own label (e.g., `slice_head(n = 10)`)
3. **Main chapter**: `{{< embed tbl-appendix.qmd#tbl-foo >}}` for the complete version

Never duplicate the code that generates a table. Define once, embed elsewhere.

## R Integration Patterns

Quarto Books with R typically use three patterns for organizing code: `.Rprofile` for global setup, `knitr::read_chunk()` for reusable labeled chunks, and direct `source()` for function libraries.

### Pattern 1: .Rprofile for automatic global loading

**When to use**: setup code and helper functions needed across **all** chapters.

**How it works**: `.Rprofile` in the project root executes automatically when RStudio opens or R starts in the project directory. Scripts loaded here become globally available without explicit `source()` or `library()` in any `.qmd` file.

**Setup** (`.Rprofile` in project root):

```r
# .Rprofile
source("scripts/setup.R")           # libraries + knitr options
source("scripts/funciones-tablas.R") # helper functions
```

**Example `scripts/setup.R`**:

```r
library(tidyverse)
library(modeldata)
library(skimr)
library(scales)
library(knitr)

# Resolve namespace conflicts
conflicted::conflicts_prefer(dplyr::filter, dplyr::lag)

# knitr options
opts_chunk$set(fig.width = 8, fig.height = 5)
```

**Example `scripts/funciones-tablas.R`**:

```r
create_num_classification_table <- function(dict, data, vars = NULL) {
  # Helper function for descriptive tables
  # ...
}

create_zero_proportion_table <- function(dict, data, top_n = NULL) {
  # Helper function for zero proportion analysis
  # ...
}
```

**Usage in any `.qmd` file** (no setup needed):

```r
#| label: zeros-structural
create_zero_proportion_table(ames_dict, ames_raw, top_n = 15)
```

**Benefits**:
- Consistent environment across all chapters
- No repeated `library()` or `source()` calls
- Helper functions instantly available
- Single point of configuration

**Caveat**: changes to `.Rprofile` require restarting the R session.

---

### Pattern 2: knitr::read_chunk() for labeled chunks

**When to use**: function definitions that you want to define in `.R` files but reference cleanly in `.qmd` files (keeps narrative separate from code).

**How it works**: Label chunks in the `.R` file with `## ---- label ----`, register them with `knitr::read_chunk()`, then use empty chunks with `#| label:` in the `.qmd` to pull in the definitions. After loading, invoke functions normally.

**Setup in `.R` file** (`scripts/data-cleaning.R`):

```r
## ---- convert-structural-zeros ----
#' Convert structural zeros to NA
#'
#' @param data Tibble or data.frame
#' @param zero_vars Character vector of variable names
#' @return Tibble with zeros converted to NA
convert_structural_zeros_to_na <- function(data, zero_vars, verbose = FALSE) {
  # ... function implementation ...
  data_out
}

## ---- create-has-indicators ----
#' Create binary has_* indicators from categorical variables
#'
#' @param data Tibble or data.frame
#' @param cat_vars Character vector of categorical variable names
#' @param none_levels Character vector of absence levels (e.g., "None", "No_Garage")
#' @return Tibble with new has_* columns
create_has_indicators <- function(data, cat_vars, none_levels) {
  # ... function implementation ...
  data_out
}
```

**Usage in `.qmd` file** (`chapters/03-data-cleaning.qmd`):

```r
#| label: register-clean
#| cache: FALSE
knitr::read_chunk("../scripts/data-cleaning.R")
```

```r
#| label: convert-structural-zeros
# Empty chunk — definition comes from the .R file
```

```r
#| label: structural-zero-clean
structural_zero_vars <- c("Pool_Area", "Garage_Area", "Mas_Vnr_Area")

# Now invoke the function that was defined in the previous chunk
ames1 <- convert_structural_zeros_to_na(ames_raw, zero_vars = structural_zero_vars)

# Access attached metadata
attr(ames1, "zero_summary") %>% knitr::kable()
```

**Pattern summary**:

1. **Register** chunks: `knitr::read_chunk("../scripts/data-cleaning.R")`
2. **Load** definitions: empty chunk with `#| label: convert-structural-zeros`
3. **Invoke** functions: `ames1 <- convert_structural_zeros_to_na(...)`

**Benefits**:
- Function definitions stay in `.R` files (easier to test, reuse)
- `.qmd` files remain narrative-focused
- Code appears in rendered output if desired
- Can show/hide definitions with `echo` option

**Note**: use `cache: FALSE` on the registration chunk to ensure chunks reload on each render.

---

### Pattern 3: Direct source() for function libraries

**When to use**: collections of functions that don't need to appear as visible chunks in the rendered output.

**How it works**: `source()` loads all functions from the `.R` file into the current environment, making them immediately callable.

**Setup in `.R` file** (`scripts/transformations.R`):

```r
# scripts/transformations.R
# Pure functions for data transformations

drop_outliers_grlivarea <- function(data, cutoff = 4000, col = "Gr_Liv_Area") {
  n_before <- nrow(data)
  data_out <- data %>% filter(.data[[col]] <= cutoff | is.na(.data[[col]]))
  n_dropped <- n_before - nrow(data_out)

  attr(data_out, "dropped_grlivarea_rows") <- n_dropped
  data_out
}

subset_for_intro <- function(data, sale_condition_col = "Sale_Condition",
                             max_area = 1500, area_col = "Gr_Liv_Area") {
  data %>%
    filter(.data[[sale_condition_col]] == "Normal") %>%
    filter(.data[[area_col]] <= max_area | is.na(.data[[area_col]]))
}

create_total_sqft <- function(data) {
  data %>%
    mutate(Total_SqFt = Total_Bsmt_SF + Gr_Liv_Area)
}
```

**Usage in `.qmd` file** (`chapters/04-transformations.qmd`):

```r
#| label: load-transformations
source("../scripts/transformations.R")
```

```r
#| label: apply-transformations
# Functions are now available
ames_tf <- drop_outliers_grlivarea(ames_clean, cutoff = 4000)
ames_tf <- subset_for_intro(ames_tf, max_area = 1500)
ames_tf <- create_total_sqft(ames_tf)
```

**Benefits**:
- Simplest pattern for utility functions
- All functions load at once
- No chunk registration needed
- Clean separation of logic and narrative

**When not to use**: if you want function definitions visible in the rendered book (use Pattern 2 instead).

---

### Path conventions

From files in `chapters/*.qmd`:
- Data: `../data/ames_clean.rds`
- Scripts: `../scripts/transformations.R`
- Images: `../images/figure.png`

From `index.qmd` (project root):
- Data: `data/ames_clean.rds`
- Scripts: `scripts/transformations.R`

Always use relative paths, never absolute paths (`/Users/...` or `C:\...`).

## Code Chunk Essentials

```r
#| label: tbl-my-table          # required for @tbl- refs
#| tbl-cap: "Table caption"     # required for @tbl- refs
#| fig-cap: "Figure caption"    # for figures instead
#| echo: true                   # show source code
#| code-fold: true              # collapsible code
#| cache: true                  # cache results
#| include: false               # execute but hide everything
#| message: false               # suppress messages
#| warning: false               # suppress warnings
```

## Bibliography

### Setup

1. Create `references.bib` with BibTeX entries
2. Reference in `_quarto.yml`: `bibliography: references.bib`
3. Optionally set CSL style: `csl: csl/style-name.csl`
4. Set citation placement: `citation-location: margin` (or `document`)

### Citing in text

```markdown
According to De Cock [@ames_decock_2011], this dataset...
The original documentation [@ames_datadict_2011] describes...
```

### References page

Last appendix, contains:

```markdown
# Referencias {.unnumbered}

::: {#refs}
:::
```

Quarto auto-populates this with all cited entries.

## Callout Blocks

Five built-in types:

```markdown
::: {.callout-note}
Informational content.
:::

::: {.callout-tip}
Helpful suggestion.
:::

::: {.callout-important}
Critical point.
:::

::: {.callout-warning}
Potential problem.
:::

::: {.callout-caution}
Proceed carefully.
:::
```

### Custom title

```markdown
::: {.callout-tip}
## Custom Title Here
Content with a custom heading.
:::
```

### Collapsible

```markdown
::: {.callout-note collapse="true"}
## Click to expand
Hidden by default.
:::
```

## Common Pitfalls

### Cross-references

| Issue | Fix |
|-------|-----|
| `@tbl-foo` shows "Unknown reference" | Add `#| tbl-cap:` to the source chunk |
| Embed renders blank | Ensure target file is in `_quarto.yml` chapters/appendices |
| Embed path not found | Paths are relative to current file, not project root |
| Duplicate label error | Never define the same label in two files; use embed instead |
| `references.qmd` empty | Add `::: {#refs} :::` div |
| Numbers show "Table" not "Tabla" | Add `crossref:` config to `_quarto.yml` |

### R Integration

| Issue | Fix |
|-------|-----|
| `.Rprofile` not loading | Must be in project root; check `getwd()`. Restart R session after changes. |
| Functions from `.Rprofile` scripts not available | Ensure `.Rprofile` has `source("scripts/filename.R")` and restart R session |
| `read_chunk()` labels not found | Use `cache: FALSE` on the registration chunk. Check chunk labels match exactly: `## ---- label ----` in .R, `#| label: label` in .qmd |
| "Object not found" after `read_chunk()` | Empty labeled chunk only loads the definition. You must still invoke the function in a separate chunk. |
| Chunk appears twice in output | Don't use both `read_chunk()` empty chunk AND explicit function definition in the .qmd. Choose one pattern. |
| `source()` fails with "cannot open file" | Check relative path from current .qmd location. From `chapters/*.qmd`, use `../scripts/`. |
| Data paths broken from chapters/ | Use `../data/` (relative to chapter location), not `data/` |
| Changes in sourced .R files not reflected | Clear knitr cache: delete `_book/` and re-render, or set `cache: FALSE` on chunks using those functions |
