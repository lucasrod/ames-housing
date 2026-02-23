# Ames Housing: Analisis del Mercado Inmobiliario en Ames, Iowa

Informe academico en formato Quarto Book para el curso **Estadistica Descriptiva** (CDR, FCEA-UdelaR). Analiza el dataset Ames Housing (De Cock, 2011) con R + tidyverse, abarcando limpieza, transformaciones, EDA, modelado predictivo y clustering.

**Autores**: Lucas Rodriguez, Nahir Silva

## Estado del proyecto

| Capitulo | Archivo | Estado |
|---|---|---|
| Prefacio | `index.qmd` | Placeholder por defecto |
| 1. Introduccion | `chapters/01-introduction.qmd` | Completo |
| 2. Descripcion de datos | `chapters/02-data-description.qmd` | Completo |
| 3. Limpieza de datos | `chapters/03-data-cleaning.qmd` | Completo |
| 4. Transformaciones | `chapters/04-transformations.qmd` | Completo |
| 5. EDA | `chapters/05-eda.qmd` | Placeholder (solo esqueleto) |
| 6. Modelado predictivo | `chapters/06-modeling.qmd` | Placeholder (solo esqueleto) |
| 7. Clustering | `chapters/07-clustering.qmd` | Placeholder (solo esqueleto) |
| 8. Conclusiones | `chapters/08-conclusions.qmd` | Placeholder (contenido generico) |
| Apendice: Diccionario | `chapters/09-data-dictionary.qmd` | Completo |
| Apendice: Tablas | `chapters/10-tbl-appendix.qmd` | Completo |
| Referencias | `chapters/references.qmd` | Completo |

## Estructura del repositorio

```
ames-housing/
├── _quarto.yml              # Configuracion del Quarto Book
├── index.qmd                # Prefacio
├── chapters/
│   ├── 01-introduction.qmd  # Objetivos, preguntas de investigacion
│   ├── 02-data-description.qmd  # Paneo inicial del dataset
│   ├── 03-data-cleaning.qmd     # Limpieza: ceros estructurales, ausencias, indicadores
│   ├── 04-transformations.qmd   # Pipeline de transformaciones (De Cock 2011)
│   ├── 05-eda.qmd               # [pendiente] Analisis exploratorio
│   ├── 06-modeling.qmd          # [pendiente] Regresion multiple, RF, GBM
│   ├── 07-clustering.qmd        # [pendiente] k-means, jerarquico
│   ├── 08-conclusions.qmd       # [pendiente] Conclusiones
│   ├── 09-data-dictionary.qmd   # Apendice: diccionario de variables
│   ├── 10-tbl-appendix.qmd      # Apendice: tablas complementarias
│   └── references.qmd           # Referencias bibliograficas
├── scripts/
│   ├── setup.R                  # Carga global: tidyverse, scales, knitr, conflicted
│   ├── funciones-tablas.R       # Funciones helper para tablas descriptivas (kable)
│   ├── data-cleaning.R          # Funciones de limpieza: zeros->NA, recodificacion, has_*
│   └── transformations.R        # Pipeline de transformaciones: outliers, total_sqft, etc.
├── data/
│   ├── data-dictionary.csv      # Diccionario: variable, tipo semantico, descripcion
│   ├── ames_clean.rds           # Dataset limpio (output cap. 3)
│   └── ames_tf_generic.rds      # Dataset transformado (output cap. 4)
├── csl/
│   └── chicago-fullnote-with-ibid.csl  # Estilo de citas
├── docs/
│   ├── adr-001-fuente-de-datos.md       # ADR: eleccion de modeldata::ames
│   ├── adr-002-ceros-estructurales.md   # ADR: ceros estructurales → NA
│   ├── adr-003-ausencias-categoricas.md # ADR: niveles None/No_* + has_*
│   ├── adr-004-discrepancias-pares.md   # ADR: resolucion de pares cat-num
│   ├── adr-005-patron-funciones-puras.md # ADR: funciones puras + atributos
│   ├── adr-006-estructura-quarto-book.md # ADR: Quarto Book + tablas embed
│   └── ...                              # HTML renders auxiliares, prompts
├── references.bib               # Bibliografia (BibTeX)
├── cover.png                    # Portada del libro
├── .Rprofile                    # Carga automatica: setup.R + funciones-tablas.R
└── test.qmd                     # Archivo de pruebas (sandbox)
```

## Pipeline de datos

```
modeldata::ames (2930 obs, 74 vars)
  │
  ├─ Cap 2: ames_raw (foto inicial, sin modificar)
  │
  ├─ Cap 3: ames_clean (data/ames_clean.rds)
  │   ├─ Ceros estructurales → NA (13 variables)
  │   ├─ Indicadores binarios has_* desde variables numericas
  │   ├─ Recodificacion de pares categorico-numerico discordantes
  │   └─ Indicadores binarios has_* desde variables categoricas
  │
  └─ Cap 4: ames_tf_generic (data/ames_tf_generic.rds)
      ├─ Filtro outliers Gr_Liv_Area > 4000 (De Cock)
      ├─ Total_SqFt = Total_Bsmt_SF + Gr_Liv_Area
      ├─ FireYN (indicador binario de chimenea)
      ├─ Indicadores has_* regenerados
      ├─ Colapso de escalas ordinales (ej. Bsmt_Cond_grp)
      ├─ Reordenamiento de baselines en factores
      └─ Transformaciones de potencia (log, sqrt, sq)
```

## Scripts R del Pipeline

El pipeline de datos se implementa mediante cuatro scripts en `scripts/`, cargados automáticamente vía `.Rprofile`:

### `scripts/setup.R`
Configuración global del proyecto, cargada al inicio de cada sesión R.

**Funciones principales**:
- Carga de paquetes: `tidyverse`, `modeldata`, `skimr`, `scales`, `knitr`
- Configuración de `conflicted` para resolver conflictos de nombres
- Opciones de knitr y display

**Uso**: se ejecuta automáticamente al abrir el proyecto (vía `.Rprofile`)

### `scripts/funciones-tablas.R`
Funciones helper para generar tablas descriptivas con formato consistente.

**Funciones principales**:
- `create_num_classification_table()` - tabla de variables numéricas con cardinalidad
- `create_cat_classification_table()` - tabla de variables categóricas con niveles
- `create_cat_levels_table()` - tabla de niveles categóricos con frecuencias
- `create_cat_absence_table()` - tabla de ausencias estructurales en categóricas
- `create_zero_proportion_table()` - tabla de proporciones de ceros en numéricas
- `create_absence_pair_table()` - métricas de ausencia por pares cat-num
- `create_present_but_zero_table()` - discrepancias: presente pero cero
- `create_absent_but_positive_table()` - discrepancias: ausente pero positivo

**Uso**: se cargan automáticamente al inicio (vía `.Rprofile`), disponibles en todos los capítulos

### `scripts/data-cleaning.R`
Funciones de limpieza implementadas en el Capítulo 3. Siguen el patrón de funciones puras con trazabilidad por atributos.

**Funciones principales**:
- `convert_structural_zeros_to_na(data, zero_vars)` - convierte ceros estructurales a `NA`
  - Adjunta atributo `"zero_summary"` con conteo de transformaciones por variable
- `create_has_num_indicators(data, num_vars, threshold)` - crea indicadores binarios `has_*` desde variables numéricas
  - Adjunta atributo `"has_num_summary"` con conteo de presencia/ausencia
- `recode_categorical_absence(data, pairs, none_levels)` - recodifica pares cat-num discordantes
  - Adjunta atributo `"recode_summary"` con conteo de recodificaciones
- `create_has_indicators(data, cat_vars, none_levels)` - crea indicadores binarios `has_*` desde variables categóricas
  - Adjunta atributo `"has_summary"` con conteo de presencia/ausencia

**Uso**: se registran vía `knitr::read_chunk("../scripts/data-cleaning.R")` en cap. 3, luego se invocan por label

**Output**: `data/ames_clean.rds`

### `scripts/transformations.R`
Pipeline de transformaciones implementado en el Capítulo 4. Aplica filtros, variables derivadas y transformaciones de potencia.

**Funciones principales**:
- `filter_outliers_decock(data)` - filtra outliers de `Gr_Liv_Area > 4000` (recomendación De Cock 2011)
- `create_total_sqft(data)` - crea `Total_SqFt = Total_Bsmt_SF + Gr_Liv_Area`
- `create_fireyn(data)` - crea indicador binario `FireYN` desde `Fireplaces`
- `regenerate_has_indicators(data)` - regenera indicadores `has_*` tras filtros
- `collapse_ordinal_scales(data)` - colapsa escalas ordinales (ej. `Bsmt_Cond` → `Bsmt_Cond_grp`)
- `reorder_factor_baselines(data)` - reordena niveles base en factores para modelado
- `apply_power_transformations(data, vars, power)` - aplica transformaciones log/sqrt/sq
  - Adjunta atributo `"transform_log"` con lista de variables transformadas

**Uso**: se registran vía `knitr::read_chunk("../scripts/transformations.R")` en cap. 4, luego se invocan por label

**Output**: `data/ames_tf_generic.rds`

## Datos

- **Fuente**: paquete R `{modeldata}` (version curada del Ames Housing de De Cock 2011)
- **Observaciones**: 2930 ventas residenciales, Ames Iowa, 2006-2010
- **Variables**: 74 (vs 80 del original; se excluyeron 8 por colinealidad con Sale_Price, se agregaron Longitude/Latitude)
- **Variable objetivo**: `Sale_Price`

## Tecnologias

- **Lenguaje**: R
- **Informe**: Quarto Book (HTML con tema cosmo)
- **Paquetes principales**: tidyverse, modeldata, skimr, knitr, scales, conflicted
- **Paquetes planificados** (caps 5-8): tidymodels, e1071, robustbase

## Decisiones de arquitectura (ADRs)

Las decisiones de diseno del proyecto estan documentadas formalmente en `docs/adr-*.md`:

| ADR | Titulo |
|---|---|
| [001](docs/adr-001-fuente-de-datos.md) | Fuente de datos: modeldata::ames vs dataset crudo |
| [002](docs/adr-002-ceros-estructurales.md) | Tratamiento de ceros estructurales en variables numericas |
| [003](docs/adr-003-ausencias-categoricas.md) | Tratamiento de ausencias estructurales en categoricas |
| [004](docs/adr-004-discrepancias-pares.md) | Resolucion de discrepancias en pares categorico-numericos |
| [005](docs/adr-005-patron-funciones-puras.md) | Patron de funciones puras con trazabilidad por atributos |
| [006](docs/adr-006-estructura-quarto-book.md) | Estructura del Quarto Book y gestion de tablas |

## Patron de diseno de funciones R

Todas las funciones de limpieza y transformacion siguen un patron consistente:
- **Funciones puras**: reciben un data.frame, devuelven uno nuevo (sin side-effects)
- **Trazabilidad via atributos**: cada funcion adjunta metadatos en atributos R (`"zero_summary"`, `"recode_summary"`, `"transform_log"`, etc.)
- **Parametro `verbose`**: controla si se imprimen mensajes y si se devuelve lista `(data, summary)` o solo el tibble
- **Validacion con `stopifnot()`**: verificacion de precondiciones en cada funcion
- **Documentacion roxygen**: todas las funciones tienen `#' @param`, `#' @return`, `#' @export`

## Como renderizar

```bash
quarto render
```

El output se genera en `_book/`.

## Proximos pasos

1. Implementar capitulo 5 (EDA): histogramas, correlaciones, scatterplots, boxplots
2. Implementar capitulo 6 (Modelado): recipe + workflow con tidymodels, regresion multiple, RF, GBM
3. Implementar capitulo 7 (Clustering): k-means, jerarquico, perfilado de clusters
4. Completar capitulo 8 (Conclusiones) con hallazgos reales
5. Actualizar el prefacio (`index.qmd`) con resumen del trabajo

## Referencias

- De Cock, D. (2011). *Ames, Iowa: Alternative to the Boston Housing Data*. Journal of Statistics Education, 19(3).
- Kuhn, M. (2024). *modeldata: Data Sets Useful for Modeling Examples*. R package.
