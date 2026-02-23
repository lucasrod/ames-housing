# Ames Housing - Instrucciones de proyecto

## Contexto

Informe academico (Quarto Book) para el curso Estadistica Descriptiva (CDR, FCEA-UdelaR).
Idioma del informe y la narrativa: **espanol**.
Idioma del codigo y nombres de variables: **ingles** (siguiendo el dataset original).

## Desviaciones respecto al CLAUDE.md global

### ADRs
- Decisiones de arquitectura documentadas en `docs/adr-*.md`.
- Las decisiones tambien se narran inline en los capitulos `.qmd`, pero los ADRs son la referencia canonica.
- Ver seccion "Decisiones de arquitectura" mas abajo para el indice completo.

### Determinismo parcial
- No hay seeds explícitos aun (se necesitaran en caps 6-7 para modelado y clustering).
- No hay lockfile de dependencias R (considerar `renv` si se necesita reproducibilidad estricta).

### Sin tracking formal de experimentos
- No se usa MLflow, DVC ni similar.
- Los resultados se documentan narrativamente en los capitulos del Quarto Book.
- Metricas y baselines se definen dentro de los capitulos de modelado (pendientes).

## Convenciones del proyecto

### Estructura Quarto Book
- Configuracion central en `_quarto.yml`
- Capitulos en `chapters/NN-nombre.qmd` (numerados, kebab-case)
- Apendices: `chapters/09-data-dictionary.qmd`, `chapters/10-tbl-appendix.qmd`
- El libro se renderiza con `quarto render` y el output va a `_book/`

### Scripts R (`scripts/`)
- `setup.R`: carga global de librerias y opciones (se ejecuta via `.Rprofile`)
- `funciones-tablas.R`: funciones helper para generar tablas descriptivas (cargado via `.Rprofile`)
- `data-cleaning.R`: funciones de limpieza (ceros -> NA, recodificacion, indicadores)
- `transformations.R`: pipeline de transformaciones (filtros, variables derivadas, potencias)

### Patron de funciones R
- Funciones puras: reciben data.frame, devuelven data.frame nuevo
- Trazabilidad via atributos R: `"zero_summary"`, `"recode_summary"`, `"has_summary"`, `"transform_log"`
- Parametro `verbose` para control de mensajes y formato de retorno
- Validacion con `stopifnot()`
- Documentacion roxygen (`#' @param`, `#' @return`)
- Los chunks de los scripts se registran con `knitr::read_chunk()` en los capitulos que los usan

### Pipeline de datos
```
modeldata::ames → ames_raw → ames_clean (data/ames_clean.rds) → ames_tf_generic (data/ames_tf_generic.rds)
```
- Cada paso es reproducible re-renderizando el capitulo correspondiente
- `ames_clean` es output del cap 3, `ames_tf_generic` es output del cap 4

### Tablas y cross-references
- Las tablas pesadas/repetidas van en `chapters/10-tbl-appendix.qmd`
- Se incrustan en otros capitulos con `{{< embed 10-tbl-appendix.qmd#label >}}`
- Cross-refs: `@tbl-nombre`, `@fig-nombre` (prefijo espanol configurado en `_quarto.yml`)

### Diccionario de variables
- Fuente de verdad: `data/data-dictionary.csv` (columnas: variable, type, description)
- Se carga en cada capitulo como `ames_dict` renombrando `type` → `tipo_semantico`

### Estilo de citas
- BibTeX en `references.bib`, estilo Chicago (fullnote-with-ibid) via `csl/`
- Citas en margen (`citation-location: margin` en `_quarto.yml`)

## Decisiones de arquitectura (ADRs)

| ADR | Titulo | Estado |
|---|---|---|
| [001](docs/adr-001-fuente-de-datos.md) | Fuente de datos: modeldata::ames | Aceptada |
| [002](docs/adr-002-ceros-estructurales.md) | Tratamiento de ceros estructurales en numericas | Aceptada |
| [003](docs/adr-003-ausencias-categoricas.md) | Tratamiento de ausencias estructurales en categoricas | Aceptada |
| [004](docs/adr-004-discrepancias-pares.md) | Resolucion de discrepancias en pares cat-num | Aceptada |
| [005](docs/adr-005-patron-funciones-puras.md) | Patron de funciones puras con trazabilidad por atributos | Aceptada |
| [006](docs/adr-006-estructura-quarto-book.md) | Estructura del Quarto Book y gestion de tablas | Aceptada |

## Pendientes conocidos

- Capitulos 5-8 son placeholders: EDA, modelado, clustering, conclusiones
- `index.qmd` tiene texto placeholder de Quarto por defecto
- Cap 8 tiene conclusiones genericas que deben actualizarse con resultados reales
- Falta inicializar git en el proyecto
- Considerar agregar seeds al implementar caps 6-7
