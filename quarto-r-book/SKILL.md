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

### .Rprofile for shared setup

```r
# .Rprofile (project root)
source("scripts/setup.R")          # libraries + options
source("scripts/funciones-tablas.R") # helper functions
```

Every chapter inherits these without explicit `source()` calls.

### knitr::read_chunk for external R scripts

Register labeled chunks from an R script:

```r
#| label: register-clean
#| cache: FALSE
knitr::read_chunk("../scripts/data-cleaning.R")
```

Then use the labels as chunk names in the `.qmd`:

```r
#| label: convert-structural-zeros
```

The chunk body comes from the R script. Keeps `.qmd` files narrative-focused.

### Direct source()

```r
source("../scripts/transformations.R")
```

Use when you need functions but don't need labeled chunks.

### Path note

From `chapters/*.qmd`, data and scripts are one level up: `../data/`, `../scripts/`.

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

| Issue | Fix |
|-------|-----|
| `@tbl-foo` shows "Unknown reference" | Add `#| tbl-cap:` to the source chunk |
| Embed renders blank | Ensure target file is in `_quarto.yml` chapters/appendices |
| Embed path not found | Paths are relative to current file, not project root |
| Duplicate label error | Never define the same label in two files; use embed instead |
| `references.qmd` empty | Add `::: {#refs} :::` div |
| Numbers show "Table" not "Tabla" | Add `crossref:` config to `_quarto.yml` |
| `.Rprofile` not loading | Must be in project root; check `getwd()` |
| `read_chunk()` labels not found | Use `cache: FALSE` on the registration chunk |
| Data paths broken from chapters/ | Use `../data/` (relative to chapter location) |
