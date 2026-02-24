---
name: quarto-r-book
description: Create and manage Quarto Book projects with R. Use when the user wants to set up a new Quarto Book, add chapters/appendices, configure cross-references between .qmd files, embed tables/figures from one chapter into another, set up bibliography/citations, configure R script loading (.Rprofile, knitr::read_chunk, source), or troubleshoot Quarto rendering issues. Covers _quarto.yml configuration, the embed shortcode system, the @ref numbering system, callout blocks, code chunk options, and multi-chapter R workflows.
---

# Quarto R Book

Build multi-chapter academic reports and books using Quarto's `book` project type with R. This skill focuses on patterns that differ from standard Quarto/R Markdown, especially cross-referencing, R script integration, and bibliography management.

## Project Scaffold

Minimal `_quarto.yml` for a book:

```yaml
project:
  type: book

book:
  title: "Book Title"
  author: [Author Name]
  date: "2025-01-01"
  chapters:
    - index.qmd
    - chapters/01-introduction.qmd
    - chapters/02-chapter-name.qmd
  appendices:
    - chapters/09-appendix.qmd
    - chapters/references.qmd

bibliography: references.bib
csl: csl/chicago-fullnote-with-ibid.csl
citation-location: margin

crossref:
  fig-title: "Figura"
  fig-prefix: "figura"
  tbl-title: "Tabla"
  tbl-prefix: "tabla"
  title-delim: ":"

format:
  html:
    toc: true
    code-fold: true
    theme: cosmo

execute:
  echo: true
  warning: true
  message: false
```

## Directory Structure

```
project/
├── _quarto.yml          # Main config
├── .Rprofile            # Auto-loads scripts on R start
├── index.qmd            # Landing page (must be first in chapters)
├── chapters/            # All chapter .qmd files here
│   ├── 01-introduction.qmd
│   ├── 02-data.qmd
│   ├── 09-appendix.qmd
│   └── references.qmd   # Bibliography (last appendix)
├── scripts/             # R scripts (.Rprofile sources from here)
│   ├── setup.R          # Libraries + knitr options
│   └── funciones.R      # Helper functions
├── data/                # Processed data (.rds files)
├── csl/                 # Citation styles
└── references.bib       # BibTeX bibliography
```

**Path rules**:
- From `chapters/*.qmd`: use `../data/`, `../scripts/`
- From `index.qmd`: use `data/`, `scripts/`

## Quarto Book Special Features

### Callout Blocks

Five types with optional collapse:

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
## Custom Title
Proceed carefully.
:::

::: {.callout-note collapse="true"}
## Click to expand
Hidden by default - useful for long tables or code.
:::
```

**Real example** (from `10-tbl-appendix.qmd`):

```markdown
::: {.callout-caution}
## Cuidado
El conjunto tiene demasiadas variables categóricas para mostrarlas todas.
:::

::: {.callout-note collapse="true"}
## Ver todas las variables categóricas
```{r}
#| label: tbl-cat-levels
create_cat_levels_table(ames_dict, skim_summary, ames_raw)
```
:::
```

### Blockquotes for Emphasis

Standard Markdown `>` for notes, summaries, or cross-references:

```markdown
> Como muestra la @tbl-metrics-global, el conjunto tiene 2930 observaciones.

> **Nota:** La tabla anterior presenta un resumen interpretativo...

> Durante la exploración inicial, también se detectaron **indicios de
> codificaciones especiales**. Estos casos tendrán tratamiento explícito
> en el capítulo de limpieza.
```

**When to use**:
- Summaries of table/figure results
- Important observations or warnings
- Cross-references to other chapters
- Multi-line notes (better than callouts for brief remarks)

## Quick Reference

### Cross-References

See `references/cross-references.md` for complete guide.

| Goal | Syntax | Use when |
|------|--------|----------|
| Display table/figure from another file | `{{< embed file.qmd#tbl-label >}}` | Avoiding code duplication (DRY) |
| Reference by number | `@tbl-label`, `@fig-label` | "see Table 2.1" in text |
| Link to section | `[text](file.qmd#anchor)` | Cross-chapter navigation |

**Critical**: embed paths are relative to current file, not project root.

### R Script Integration

See `references/r-scripts.md` for complete guide with DRY/SOLID justification.

| Pattern | When to use | Loaded |
|---------|-------------|--------|
| `.Rprofile` | Functions in **all** chapters | Automatic on R start |
| `read_chunk()` | Show function source in output | Per-chapter, explicit |
| `source()` | Functions available, not visible | Per-chapter, explicit |

**Pattern 1 example** (global):
```r
# .Rprofile
source("scripts/setup.R")  # tidyverse, knitr opts
```

**Pattern 2 example** (show source):
```r
#| label: register
knitr::read_chunk("../scripts/functions.R")
```

**Pattern 3 example** (hide source):
```r
source("../scripts/transformations.R")
```

### Bibliography

See `references/bibliography.md` for complete guide with BibTeX entry types.

| Entry type | Use for | Cite as |
|------------|---------|---------|
| `@article` | Journal articles | `[@decock_2011]` |
| `@Manual` | R packages, docs | `[@modeldata2024]` |
| `@misc` | Kaggle, GitHub, web | `[@kaggle_cleaning]` |

**Setup**:
```yaml
bibliography: references.bib
csl: csl/chicago-fullnote-with-ibid.csl
citation-location: margin
```

**References page** (last appendix):
```markdown
# Referencias {.unnumbered}

::: {#refs}
:::
```

## Code Chunk Essentials

```r
#| label: tbl-my-table          # required for @tbl- refs
#| tbl-cap: "Table caption"     # required for @tbl- refs
#| fig-cap: "Figure caption"    # for figures
#| echo: true                   # show source code
#| code-fold: true              # collapsible code
#| cache: true                  # cache results
#| include: false               # execute but hide
```

## Common Pitfalls

| Issue | Fix |
|-------|-----|
| `@tbl-foo` shows "Unknown reference" | Add `#| tbl-cap:` to source chunk |
| Embed renders blank | Add target file to `_quarto.yml` chapters/appendices |
| Embed path not found | Paths relative to current file: use `../` from `chapters/` |
| `.Rprofile` not loading | Must be in project root. Restart R session after changes. |
| `read_chunk()` labels not found | Use `cache: FALSE` on registration chunk. Check label match exactly. |
| Functions not available after `read_chunk()` | Empty chunk loads definition. Must invoke function in separate chunk. |
| Bibliography empty | Add `::: {#refs} :::` to references.qmd |
| Citation shows `[@key]` literally | Check key exists in references.bib |

## Rendering

```bash
quarto render              # Render entire book
quarto preview             # Live preview with auto-reload
quarto render index.qmd    # Render single file (for testing)
```

Output: `_book/`

Add to `.gitignore`:
```
/_book/
/_site/
/.quarto/
*.embed.ipynb
```
