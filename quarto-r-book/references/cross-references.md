# Cross-References in Quarto Book: Complete Guide

Quarto Book has two distinct cross-referencing systems that work together. Understanding when and how to use each is critical for multi-chapter projects.

## System A: Embed Shortcode `{{< embed >}}`

### What it does

Renders a code chunk from another `.qmd` file and displays its output inline in the current file. The chunk executes in its source file's context but the output appears where you place the shortcode.

### Syntax

```markdown
{{< embed filename.qmd#chunk-label >}}
{{< embed filename.qmd#chunk-label echo=TRUE >}}
```

### Requirements

1. The target chunk **must** have a `#| label:` with a recognized prefix (`tbl-`, `fig-`, etc.)
2. The target file **must** be listed in `_quarto.yml` under `chapters:` or `appendices:`
3. The chunk label must be unique across the entire book

### Path behavior (critical)

Paths are **relative to the file containing the embed shortcode**, not the project root.

```
project/
  _quarto.yml
  index.qmd
  chapters/
    02-data-description.qmd   # ← embedding file
    09-data-dictionary.qmd    # ← source file
    10-tbl-appendix.qmd       # ← source file
```

From `chapters/02-data-description.qmd`, reference sibling files by name only:

```markdown
<!-- CORRECT: sibling file in same directory -->
{{< embed 10-tbl-appendix.qmd#tbl-metrics-global echo=TRUE >}}

<!-- WRONG: don't use the chapters/ prefix from within chapters/ -->
{{< embed chapters/10-tbl-appendix.qmd#tbl-metrics-global >}}
```

From `index.qmd` (project root), you would need the subdirectory:

```markdown
<!-- From root-level file, include the path -->
{{< embed chapters/10-tbl-appendix.qmd#tbl-metrics-global >}}
```

### Options

| Option | Values | Effect |
|--------|--------|--------|
| `echo` | `TRUE` / `FALSE` | Show/hide the source code alongside the output |

### How it works internally

Quarto creates `.embed.ipynb` intermediary files during rendering. These are build artifacts and should be in `.gitignore`.

### Real examples from a project

In `chapters/02-data-description.qmd`, embedding from two different source files:

```markdown
<!-- From appendix chapter 9 (dictionary) -->
{{< embed 09-data-dictionary.qmd#tbl-data-dictionary-first10 echo=TRUE >}}

<!-- From appendix chapter 10 (tables) -->
{{< embed 10-tbl-appendix.qmd#tbl-metrics-global echo=TRUE >}}
{{< embed 10-tbl-appendix.qmd#tbl-type-vs-semantic echo=TRUE >}}
```

In `chapters/03-data-cleaning.qmd`, embedding discrepancy analysis tables:

```markdown
{{< embed 10-tbl-appendix.qmd#tbl-metrics-global echo=TRUE >}}
{{< embed 10-tbl-appendix.qmd#tbl-absence-pair echo=TRUE >}}
{{< embed 10-tbl-appendix.qmd#tbl-present-but-zero echo=TRUE >}}
{{< embed 10-tbl-appendix.qmd#tbl-absent-but-positive echo=TRUE >}}
```

## System B: Inline References `@prefix-label`

### What it does

Creates auto-numbered references to tables, figures, equations, and sections. Quarto handles numbering by chapter (e.g., "Tabla 2.1", "Figure A.1").

### Syntax

```markdown
As shown in @tbl-metrics-global, the dataset has 2930 observations.
See @fig-price-distribution for the histogram.
```

### Requirements

The target chunk must have **both**:

1. `#| label: tbl-xxx` (with the correct prefix)
2. `#| tbl-cap: "Caption text"` (or `fig-cap` for figures)

```r
#| label: tbl-metrics-global
#| tbl-cap: "Global metrics for the Ames dataset"
tibble(metric = c("Obs", "Vars"), value = c(2930, 74)) %>% kable()
```

Without the caption, the `@tbl-` reference will produce "Unknown reference".

### Prefix table

| Prefix | Object type | Caption option | Reference syntax |
|--------|-------------|----------------|------------------|
| `tbl-` | Table | `tbl-cap` | `@tbl-label` |
| `fig-` | Figure | `fig-cap` | `@fig-label` |
| `eq-`  | Equation | — | `@eq-label` |
| `sec-` | Section | — | `@sec-label` |

### Localization via `_quarto.yml`

```yaml
crossref:
  fig-title: "Figura"
  fig-prefix: "figura"
  tbl-title: "Tabla"
  tbl-prefix: "tabla"
  title-delim: ":"
```

With this config, `@tbl-metrics-global` renders as "tabla 2.1" in running text, and the table heading shows "Tabla 2.1: Global metrics...".

### Numbering scheme

- Chapters: `Tabla 2.1`, `Tabla 2.2`, etc.
- Appendices: `Tabla A.1`, `Tabla B.1`, etc.
- Numbering is automatic and cross-chapter.

## Interaction Between the Two Systems

### Embedded chunks carry their labels

When you embed a chunk via `{{< embed >}}`, its label travels with it. So `@tbl-metrics-global` works in:
- The source file (`10-tbl-appendix.qmd`) where the chunk is defined
- Any chapter that embeds it (`02-data-description.qmd`, `03-data-cleaning.qmd`)
- Any other chapter in the book (references resolve globally)

### Caption is set once

The `#| tbl-cap:` in the source chunk is the single source of truth. You don't re-declare captions when embedding.

### Don't duplicate labels

Never define the same `#| label:` in two different `.qmd` files. This causes build errors or ambiguous references.

**Wrong** (duplicate label):
```
# In 10-tbl-appendix.qmd
#| label: tbl-metrics-global

# In 02-data-description.qmd
#| label: tbl-metrics-global   ← CONFLICT
```

**Right** (embed instead of duplicate):
```
# In 10-tbl-appendix.qmd
#| label: tbl-metrics-global

# In 02-data-description.qmd
{{< embed 10-tbl-appendix.qmd#tbl-metrics-global >}}
```

## Section Cross-References

### Adding section IDs

```markdown
## Resultados del EDA {#sec-resultados}
```

### Referencing sections

Two styles:

```markdown
<!-- Markdown link (no auto-numbering) -->
See [the cleaning chapter](03-data-cleaning.qmd#sec-id).

<!-- Quarto @ref (auto-numbered if enabled) -->
See @sec-resultados for details.
```

Cross-chapter links use the target filename:

```markdown
See [the initial review](03-data-cleaning.qmd#revision-del-estado-de-limpieza-inicial).
```

## Table Management: DRY with Embeds

### The problem

Large tables (>12-15 rows) clutter main chapters and duplicate code if shown in multiple places.

### The pattern

1. **Appendix file** (`tbl-appendix.qmd`): defines the full table with its own label/caption
2. **Main chapter**: shows a subset inline (e.g., first 10 rows) with its own label/caption
3. **Main chapter**: embeds the full version from the appendix for readers who want the complete data

### Concrete example: variable dictionary

In `09-data-dictionary.qmd` (appendix), define both tables:

```r
#| label: tbl-data-dictionary
#| tbl-cap: "Diccionario de variables"
ames_dict %>% arrange(variable) %>% kable()
```

```r
#| label: tbl-data-dictionary-first10
#| tbl-cap: "Primeras 10 variables del diccionario"
ames_dict %>% slice_head(n = 10) %>% kable()
```

In `02-data-description.qmd` (main chapter), embed the preview:

```markdown
{{< embed 09-data-dictionary.qmd#tbl-data-dictionary-first10 echo=TRUE >}}

For the complete dictionary see [the appendix](09-data-dictionary.html).
```

### Concrete example: metrics tables

In `10-tbl-appendix.qmd`, define the full table once:

```r
#| label: tbl-metrics-global
#| tbl-cap: "Metricas globales del conjunto Ames"
```

In `02-data-description.qmd` and `03-data-cleaning.qmd`, embed it:

```markdown
{{< embed 10-tbl-appendix.qmd#tbl-metrics-global echo=TRUE >}}
> As shown in @tbl-metrics-global, the dataset has 2930 observations.
```

The code that generates the table exists in exactly one place.

## Label Naming Conventions

- Use `tbl-` prefix for tables, `fig-` for figures (mandatory for refs to work)
- Use `kebab-case`: `tbl-metrics-global`, not `tbl_metrics_global`
- Be descriptive: `tbl-cat-classification` not `tbl-1`
- Labels persist across chapters, so use names that make sense globally

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "Unknown reference @tbl-foo" | Missing `tbl-cap` in source chunk | Add `#| tbl-cap: "..."` to the chunk |
| "Unknown reference @tbl-foo" | Label prefix mismatch | Ensure chunk label starts with `tbl-` |
| Embed shows nothing | Target file not in `_quarto.yml` | Add it to `chapters:` or `appendices:` |
| Embed shows nothing | Wrong path | Check if path is relative to current file |
| Duplicate label error | Same label in two `.qmd` files | Use embed instead of duplicating |
| Wrong numbering (e.g., "Table" not "Tabla") | Missing crossref config | Add `crossref:` section to `_quarto.yml` |
| `.embed.ipynb` files in git | Missing gitignore entry | Add `*.embed.ipynb` to `.gitignore` |
