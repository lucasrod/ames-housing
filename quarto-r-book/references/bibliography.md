# Bibliography and Citations: Complete Guide

Quarto Books use BibTeX for bibliography management. This guide covers setup, entry types, and citation syntax based on real project usage.

## Setup

**`references.bib`** (project root):
```bibtex
@article{ames_decock_2011,
  author  = {De Cock, Dean},
  title   = {Ames, Iowa: Alternative to the Boston Housing Data},
  journal = {Journal of Statistics Education},
  volume  = {19},
  number  = {3},
  year    = {2011},
  url     = {https://jse.amstat.org/v19n3/decock.pdf}
}
```

**`_quarto.yml`**:
```yaml
bibliography: references.bib
csl: csl/chicago-fullnote-with-ibid.csl  # optional
citation-location: margin                # or "document"
```

**CSL files**: Download from [Zotero Style Repository](https://www.zotero.org/styles)
- `chicago-fullnote-with-ibid.csl` - Chicago with ibid
- `apa.csl` - APA 7th edition
- `ieee.csl` - IEEE

Place in `csl/` directory.

---

## BibTeX Entry Types

### @article - Journal Articles

```bibtex
@article{ames_decock_2011,
  author  = {De Cock, Dean},
  title   = {Ames, Iowa: Alternative to the Boston Housing Data},
  journal = {Journal of Statistics Education},
  volume  = {19},
  number  = {3},
  year    = {2011},
  url     = {https://jse.amstat.org/v19n3/decock.pdf}
}
```

**Required**: `author`, `title`, `journal`, `year`
**Optional**: `volume`, `number`, `pages`, `doi`, `url`

### @Manual - R Packages & Documentation

```bibtex
@Manual{modeldata2024,
  title = {modeldata: Data Sets Useful for Modeling Examples},
  author = {Max Kuhn},
  year = {2024},
  note = {R package version 1.4.0},
  url = {https://CRAN.R-project.org/package=modeldata}
}

@Manual{ames_datadict_2011,
  author = {De Cock, Dean},
  title = {Data Documentation for the Ames Housing Data Set},
  year = {2011},
  howpublished = {\url{https://jse.amstat.org/v19n3/decock/DataDocumentation.txt}},
  note = {Supplement to De Cock (2011)}
}
```

**Required**: `title`
**Typical**: `author`, `year`, `note`, `url`, `howpublished`

### @misc - Web Resources

Kaggle notebooks, GitHub repos, tutorials:

```bibtex
@misc{ames_kaggle_cleaning,
  author = {Sharma, Jeevika},
  title = {Ultimate Guide to Data Cleaning Techniques},
  year = {2022},
  url = {https://www.kaggle.com/code/jeevikasharma2003/ultimate-guide},
  note = {Kaggle notebook}
}

@misc{sklearn_mooc,
  author = {INRIA},
  title = {The Ames housing dataset - scikit-learn MOOC},
  year = {2021},
  url = {https://inria.github.io/scikit-learn-mooc/python_scripts/datasets_ames_housing.html}
}
```

**Required**: `title`
**Typical**: `author`, `year`, `url`, `note`

### @book - Books

```bibtex
@book{wickham2023r,
  author = {Wickham, Hadley and Çetinkaya-Rundel, Mine and Grolemund, Garrett},
  title = {R for Data Science},
  edition = {2nd},
  year = {2023},
  publisher = {O'Reilly Media},
  url = {https://r4ds.hadley.nz/}
}
```

---

## Citation Syntax

### Basic

```markdown
According to De Cock [@ames_decock_2011], this dataset...
```
**Renders**: According to De Cock (De Cock, 2011), this dataset...

### Citation Only

```markdown
This dataset is an alternative [@ames_decock_2011].
```
**Renders**: This dataset is an alternative (De Cock, 2011).

### Multiple Citations

```markdown
Several studies [@ames_decock_2011; @modeldata2024; @kaggle_cleaning] analyzed...
```
**Renders**: Several studies (De Cock, 2011; Kuhn, 2024; Sharma, 2022) analyzed...

### With Prefix/Suffix

```markdown
[See @ames_decock_2011, pp. 33-35, for details]
```
**Renders**: (See De Cock, 2011, pp. 33-35, for details)

### Suppress Author

```markdown
De Cock [-@ames_decock_2011] introduced this dataset.
```
**Renders**: De Cock (2011) introduced this dataset.

---

## References Page

Last appendix (`chapters/references.qmd`):

```markdown
---
title: "References"
---

# Referencias {.unnumbered}

::: {#refs}
:::
```

**`_quarto.yml`**:
```yaml
book:
  appendices:
    - chapters/09-appendix.qmd
    - chapters/references.qmd  # LAST
```

**How it works**:
- `{.unnumbered}` prevents numbering
- `::: {#refs} :::` injects cited entries
- Only cited entries appear (auto-sorted)

---

## Real Project Examples

### Academic Article
```bibtex
@article{ames_decock_2011,
  author  = {De Cock, Dean},
  title   = {Ames, Iowa: Alternative to the Boston Housing Data},
  journal = {Journal of Statistics Education},
  volume  = {19},
  number  = {3},
  year    = {2011},
  url     = {https://jse.amstat.org/v19n3/decock.pdf}
}
```

**Cited as**:
```markdown
El conjunto de datos *Ames Housing* [@ames_decock_2011] documenta transacciones...
```

### Documentation
```bibtex
@Manual{ames_datadict_2011,
  author = {De Cock, Dean},
  title = {Data Documentation for the Ames Housing Data Set},
  year = {2011},
  howpublished = {\url{https://jse.amstat.org/v19n3/decock/DataDocumentation.txt}}
}
```

**Cited as**:
```markdown
La documentación original [@ames_datadict_2011] describe los niveles...
```

### R Package
```bibtex
@Manual{modeldata2024,
  title = {modeldata: Data Sets Useful for Modeling Examples},
  author = {Max Kuhn},
  year = {2024},
  url = {https://CRAN.R-project.org/package=modeldata}
}
```

**Cited as**:
```markdown
Trabajaremos con `{modeldata}` [@modeldata2024].
```

### Kaggle
```bibtex
@misc{ames_kaggle_cleaning,
  author = {Sharma, Jeevika},
  title = {Ultimate Guide to Data Cleaning Techniques},
  year = {2022},
  url = {https://www.kaggle.com/code/jeevikasharma2003/ultimate-guide}
}
```

**Cited as**:
```markdown
Otros análisis [@ames_kaggle_cleaning; @ames_kaggle_eda_fe] implementan...
```

---

## Common Issues

| Issue | Fix |
|-------|-----|
| `[@key]` shows literally | Key not in `references.bib` |
| "???" in citation | BibTeX syntax error |
| Reference not in list | Not cited in text |
| Wrong style | Check/download correct CSL |
| "References" numbered | Add `{.unnumbered}` |
| Empty references page | Add `::: {#refs} :::` |
| URL not clickable | Add `url = {https://...}` |

---

## BibTeX from Google Scholar

Quick way to get entries:
1. Search on [Google Scholar](https://scholar.google.com/)
2. Click "Cite" below result
3. Click "BibTeX"
4. Copy into `references.bib`
5. Cite with `[@key]`
