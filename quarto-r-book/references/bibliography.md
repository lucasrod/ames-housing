# Bibliography and Citations: Complete Guide

Quarto Books use BibTeX for bibliography management with flexible citation styles (Chicago, APA, IEEE, etc.). This guide covers setup, BibTeX entry types, citation syntax, and examples from real projects.

## Setup

### Required files

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
csl: csl/chicago-fullnote-with-ibid.csl  # optional, defaults to Chicago
citation-location: margin                # or "document"
```

### Citation Style Language (CSL)

Download `.csl` files from:
- Zotero Style Repository: https://www.zotero.org/styles
- GitHub CSL repository: https://github.com/citation-style-language/styles

Common styles:
- `chicago-fullnote-with-ibid.csl` - Chicago (notes with ibid)
- `apa.csl` - APA 7th edition
- `ieee.csl` - IEEE
- `nature.csl` - Nature journal

Place in `csl/` directory, reference in `_quarto.yml`.

### Citation Location

**Margin** (recommended for HTML books):
```yaml
citation-location: margin
```
Citations appear in the page margin, keeping main text clean.

**Document** (standard for PDF):
```yaml
citation-location: document
```
Citations appear as footnotes or inline, depending on style.

---

## BibTeX Entry Types

### @article - Journal Articles

Academic papers, peer-reviewed articles.

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

**Required fields**: `author`, `title`, `journal`, `year`
**Optional**: `volume`, `number`, `pages`, `doi`, `url`

### @Manual - Software Documentation

R packages, technical manuals, documentation.

```bibtex
@Manual{modeldata2024,
  title = {modeldata: Data Sets Useful for Modeling Examples},
  author = {Max Kuhn},
  year = {2024},
  note = {R package version 1.4.0},
  url = {https://CRAN.R-project.org/package=modeldata}
}
```

**Required fields**: `title`
**Typical**: `author`, `year`, `note`, `url`

**Alternative for documentation**:
```bibtex
@Manual{ames_datadict_2011,
  author = {De Cock, Dean},
  title = {Data Documentation for the Ames Housing Data Set},
  year = {2011},
  howpublished = {\url{https://jse.amstat.org/v19n3/decock/DataDocumentation.txt}},
  note = {Supplement to De Cock (2011)}
}
```

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

**Required fields**: `author`, `title`, `publisher`, `year`
**Optional**: `edition`, `isbn`, `url`

### @misc - Web Resources

Kaggle notebooks, GitHub repos, blog posts, tutorials.

```bibtex
@misc{ames_kaggle_cleaning,
  author = {Sharma, Jeevika},
  title = {Ultimate Guide to Data Cleaning Techniques},
  year = {2022},
  url = {https://www.kaggle.com/code/jeevikasharma2003/ultimate-guide-to-data-cleaning-techniques},
  note = {Kaggle notebook}
}
```

**Required fields**: `title`
**Typical**: `author`, `year`, `url`, `note`

**GitHub repositories**:
```bibtex
@misc{sklearn_mooc,
  author = {INRIA},
  title = {The Ames housing dataset - scikit-learn MOOC},
  year = {2021},
  url = {https://inria.github.io/scikit-learn-mooc/python_scripts/datasets_ames_housing.html},
  note = {GitHub: https://github.com/INRIA/scikit-learn-mooc}
}
```

### @online - Online Resources

Alternative to `@misc` for web-first content.

```bibtex
@online{r4ds_online,
  author = {Wickham, Hadley},
  title = {R for Data Science},
  year = {2023},
  url = {https://r4ds.hadley.nz/},
  urldate = {2024-01-15}
}
```

**Use when**: The resource only exists online (no print equivalent).

### @inproceedings - Conference Papers

```bibtex
@inproceedings{chen2016xgboost,
  author = {Chen, Tianqi and Guestrin, Carlos},
  title = {XGBoost: A Scalable Tree Boosting System},
  booktitle = {Proceedings of the 22nd ACM SIGKDD},
  year = {2016},
  pages = {785--794},
  doi = {10.1145/2939672.2939785}
}
```

---

## Citation Syntax

### Basic Citation

```markdown
According to De Cock [@ames_decock_2011], this dataset...
```

**Renders as**: According to De Cock (De Cock, 2011), this dataset...

### Citation Only

```markdown
This dataset is an alternative to Boston Housing [@ames_decock_2011].
```

**Renders as**: This dataset is an alternative to Boston Housing (De Cock, 2011).

### Multiple Citations

```markdown
Several studies [@ames_decock_2011; @modeldata2024; @kaggle_cleaning] have analyzed...
```

**Renders as**: Several studies (De Cock, 2011; Kuhn, 2024; Sharma, 2022) have analyzed...

### Citation with Prefix/Suffix

```markdown
[See @ames_decock_2011, pp. 33-35, for details]
```

**Renders as**: (See De Cock, 2011, pp. 33-35, for details)

### Suppress Author

```markdown
De Cock [-@ames_decock_2011] introduced this dataset.
```

**Renders as**: De Cock (2011) introduced this dataset.

---

## References Page

Last appendix in the book (e.g., `chapters/references.qmd`):

```markdown
---
title: "References"
---

# Referencias {.unnumbered}

::: {#refs}
:::
```

**How it works**:
- `{.unnumbered}` prevents "Appendix C: References" numbering
- `::: {#refs} :::` is a special div where Quarto injects all cited entries
- Only cited entries appear (not everything in `references.bib`)
- Sorted alphabetically by author last name (or by style rules)

**`_quarto.yml` configuration**:
```yaml
book:
  chapters:
    - index.qmd
    - chapters/01-intro.qmd
  appendices:
    - chapters/09-appendix.qmd
    - chapters/references.qmd  # Must be LAST
```

---

## Real Project Examples

From `references.bib` in the Ames Housing project:

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

### Technical Documentation
```bibtex
@Manual{ames_datadict_2011,
  author = {De Cock, Dean},
  title = {Data Documentation for the Ames Housing Data Set},
  year = {2011},
  howpublished = {\url{https://jse.amstat.org/v19n3/decock/DataDocumentation.txt}},
  note = {Supplement to De Cock (2011)}
}
```

**Cited as**:
```markdown
La documentación original [@ames_datadict_2011] describe los niveles de cada variable...
```

### R Package
```bibtex
@Manual{modeldata2024,
  title = {modeldata: Data Sets Useful for Modeling Examples},
  author = {Max Kuhn},
  year = {2024},
  note = {R package version 1.4.0},
  url = {https://CRAN.R-project.org/package=modeldata}
}
```

**Cited as**:
```markdown
Trabajaremos con la versión curada del conjunto `ames` incluida en el paquete
`{modeldata}` [@modeldata2024].
```

### Kaggle Notebook
```bibtex
@misc{ames_kaggle_cleaning,
  author = {Sharma, Jeevika},
  title = {Ultimate Guide to Data Cleaning Techniques},
  year = {2022},
  url = {https://www.kaggle.com/code/jeevikasharma2003/ultimate-guide-to-data-cleaning-techniques},
  note = {Kaggle notebook}
}
```

**Cited as**:
```markdown
Otros análisis del dataset [@ames_kaggle_cleaning; @ames_kaggle_eda_fe] implementan...
```

---

## Inline vs Narrative Citations

### Narrative Citation
Author name is part of the sentence:

```markdown
De Cock [@ames_decock_2011] propone este dataset como alternativa...
```

**Renders as**: De Cock (2011) propone este dataset como alternativa...

### Parenthetical Citation
Citation is separate from sentence structure:

```markdown
Este dataset es una alternativa moderna [@ames_decock_2011].
```

**Renders as**: Este dataset es una alternativa moderna (De Cock, 2011).

---

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Citation shows `[@key]` literally | Key not in `references.bib` | Check spelling, add entry |
| Citation shows "???" | Entry exists but has errors | Validate BibTeX syntax |
| Reference not appearing in list | Entry not cited in text | Add citation somewhere in book |
| Wrong citation style | Missing or incorrect CSL | Download correct `.csl`, update `_quarto.yml` |
| "References" heading numbered | Missing `{.unnumbered}` | Add to heading: `# Referencias {.unnumbered}` |
| References empty | Missing `::: {#refs} :::` | Add div to references.qmd |
| URL not clickable | Missing `url` field | Add `url = {https://...}` to entry |
| Author name wrong format | Incorrect BibTeX name format | Use `Last, First` or `Last, First and Last2, First2` |

---

## Advanced: Custom BibTeX Fields

### DOI (Digital Object Identifier)
```bibtex
@article{example,
  doi = {10.1000/example}
}
```

### ISBN (Books)
```bibtex
@book{example,
  isbn = {978-1-234-56789-0}
}
```

### Editor (Edited Books)
```bibtex
@book{example,
  editor = {Smith, John and Doe, Jane},
  title = {Edited Volume Title}
}
```

### Multiple Authors
```bibtex
@article{example,
  author = {Smith, John and Doe, Jane and Lee, Amy}
}
```

For 3+ authors, some styles automatically use "et al." in citations.

---

## Citation Management Tools

Generate BibTeX entries automatically:

- **Zotero** (free): https://www.zotero.org/
- **Mendeley** (free): https://www.mendeley.com/
- **JabRef** (free, open-source): https://www.jabref.org/
- **Google Scholar**: Click "Cite" → "BibTeX"
- **DOI2BibTeX**: https://doi2bib.org/

**Workflow**:
1. Add paper to citation manager
2. Export as BibTeX
3. Paste into `references.bib`
4. Cite in `.qmd` with `[@key]`
