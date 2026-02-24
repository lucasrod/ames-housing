# ADR-007: MLflow para rastreo de experimentos en modelado y clustering

**Estado**: Aceptada
**Fecha**: 2025-02-24
**Capítulos relacionados**: 06-modeling.qmd, 07-clustering.qmd
**Scripts relacionados**: scripts/modeling.R, scripts/clustering.R

## Contexto

Los capítulos 6 (modelado predictivo) y 7 (clustering) requieren comparar múltiples modelos, recetas y configuraciones de hiperparámetros. Sin un sistema de tracking, esto implica:
- Gestión manual de métricas en spreadsheets o comentarios
- Reproducibilidad limitada (¿qué hiperparámetros usó cada run?)
- Dificultad para comparar runs históricos
- Pérdida de artefactos (modelos ajustados, gráficos de residuales, importancia de variables)

Se requiere un sistema que:
1. Registre automáticamente parámetros, métricas y artefactos
2. Permita comparación sistemática de modelos
3. No contamine los capítulos .qmd con código de logging
4. Sea compatible con tidymodels y el patrón de funciones puras (ADR-005)

## Decisión

Usar **MLflow** para rastreo de experimentos con la siguiente arquitectura:

### Dos experimentos separados

1. **`ames-regression`**: modelos predictivos (LR, RF, GBM) con métricas RMSE, R², MAE
2. **`ames-clustering`**: k-means, jerárquico con métricas silhouette, WSS, BSS/TSS ratio

**Justificación**: esquemas de métricas incompatibles. Mezclarlos confunde el UI de MLflow.

### Patrón de integración

Sigue la convención del proyecto (ADR-005, ADR-006):

```
scripts/
├── modeling.R         # Funciones puras: recipes, specs, run_model()
└── clustering.R       # Funciones puras: make_cluster_data(), run_kmeans(), run_hierarchical()

chapters/
├── 06-modeling.qmd    # Narrativa + invocación de funciones
└── 07-clustering.qmd  # Narrativa + invocación de funciones
```

**Principio**: el código de MLflow vive en `scripts/`, los capítulos `.qmd` permanecen limpios y enfocados en la narrativa. Los capítulos llaman funciones; las funciones registran en MLflow.

### Estructura de scripts/modeling.R

```r
# Recipes (puras, sin side-effects)
make_base_recipe <- function(data) {
  recipe(Sale_Price ~ ., data = data) |>
    step_log(Sale_Price, base = 10) |>
    step_rm(matches("^PID$|^Order$")) |>
    step_impute_median(all_numeric_predictors()) |>
    step_impute_mode(all_nominal_predictors()) |>
    step_other(all_nominal_predictors(), threshold = 0.05) |>
    step_dummy(all_nominal_predictors(), one_hot = FALSE) |>
    step_zv(all_predictors()) |>
    step_normalize(all_numeric_predictors())
}

make_extended_recipe <- function(data) {
  make_base_recipe(data) |>
    step_interact(~ Total_SqFt:starts_with("Neighborhood")) |>
    step_poly(Total_SqFt, Gr_Liv_Area, degree = 2)
}

# Model specs
make_lm_spec <- function() {
  linear_reg() |> set_engine("lm") |> set_mode("regression")
}

make_rf_spec <- function(mtry = 10, trees = 500, min_n = 5) {
  rand_forest(mtry = mtry, trees = trees, min_n = min_n) |>
    set_engine("ranger", importance = "impurity") |>
    set_mode("regression")
}

make_gbm_spec <- function(trees = 500, learn_rate = 0.05, tree_depth = 6, min_n = 10) {
  boost_tree(trees = trees, learn_rate = learn_rate,
             tree_depth = tree_depth, min_n = min_n) |>
    set_engine("xgboost") |> set_mode("regression")
}

# Core runner: envuelve workflow en MLflow run
run_model <- function(model_name, recipe, spec, train, test, cv_folds,
                      recipe_name = "base_recipe", extra_params = list()) {

  wf <- workflow() |> add_recipe(recipe) |> add_model(spec)

  with(mlflow_start_run(run_name = glue::glue("{model_name}__{recipe_name}")), {

    # Log params
    mlflow_log_param("model", model_name)
    mlflow_log_param("recipe", recipe_name)
    mlflow_log_param("cv_folds", cv_folds$id |> length())
    mlflow_log_param("train_rows", nrow(train))

    # Log hyperparams del spec
    purrr::iwalk(spec$args, function(val, nm) {
      v <- tryCatch(rlang::eval_tidy(val), error = function(e) as.character(val))
      if (!is.null(v)) mlflow_log_param(nm, v)
    })

    # CV
    cv_results <- fit_resamples(wf, resamples = cv_folds,
                                 metrics = metric_set(rmse, rsq, mae))
    cv_metrics <- collect_metrics(cv_results)
    cv_metrics |>
      dplyr::filter(.metric %in% c("rmse", "rsq", "mae")) |>
      dplyr::rowwise() |>
      dplyr::group_walk(function(row, key) {
        mlflow_log_metric(glue::glue("cv_{row$.metric}_mean"), row$mean)
        mlflow_log_metric(glue::glue("cv_{row$.metric}_sd"), row$std_err)
      })

    # Fit final en train completo
    fitted_wf <- fit(wf, data = train)

    # Test metrics
    test_preds <- predict(fitted_wf, new_data = test) |>
      bind_cols(test |> select(Sale_Price))
    test_metrics <- metrics(test_preds, truth = Sale_Price, estimate = .pred)
    test_metrics |>
      dplyr::filter(.metric %in% c("rmse", "rsq", "mae")) |>
      dplyr::rowwise() |>
      dplyr::group_walk(function(row, key) {
        mlflow_log_metric(glue::glue("test_{row$.metric}"), row$.estimate)
      })

    # Artifacts: VIP plot (RF/GBM), residual plot, workflow .rds
    # [código de plots omitido por brevedad - ver scripts/modeling.R]

    mlflow_set_tag("framework", "tidymodels")
    mlflow_set_tag("dataset", "ames_tf_generic")
    mlflow_set_tag("chapter", "06-modeling")
  })

  invisible(list(workflow = fitted_wf, cv_metrics = cv_metrics,
                 test_preds = test_preds, test_metrics = test_metrics))
}

# Helper: tabla comparativa de runs
get_model_comparison_table <- function(experiment_name = "ames-regression") {
  client <- mlflow_client()
  exp <- mlflow_get_experiment_by_name(experiment_name)
  runs <- mlflow_search_runs(experiment_ids = exp$experiment_id,
                              filter_string = "status = 'FINISHED'")
  runs |>
    select(run_id, model = `params.model`, recipe = `params.recipe`,
           cv_rmse = `metrics.cv_rmse_mean`, cv_rsq = `metrics.cv_rsq_mean`,
           test_rmse = `metrics.test_rmse`, test_rsq = `metrics.test_rsq`) |>
    arrange(test_rmse)
}
```

### Estructura de scripts/clustering.R

```r
# Preparación de datos para clustering (sin target)
make_cluster_data <- function(data, exclude_vars = c("Sale_Price", "PID", "Order")) {
  data |>
    select(-any_of(exclude_vars)) |>
    select(where(is.numeric)) |>
    drop_na() |>
    scale()
}

# k-means con MLflow
run_kmeans <- function(data_scaled, k, nstart = 25, max_iter = 300, run_name = NULL) {

  rn <- run_name %||% glue::glue("kmeans_k{k}")

  with(mlflow_start_run(run_name = rn), {
    mlflow_log_param("algorithm", "kmeans")
    mlflow_log_param("k", k)
    mlflow_log_param("nstart", nstart)

    set.seed(2025)
    km <- kmeans(data_scaled, centers = k, nstart = nstart, iter.max = max_iter)

    # Métricas de calidad
    mlflow_log_metric("total_withinss", km$tot.withinss)
    mlflow_log_metric("bss_tss_ratio", km$betweenss / km$totss)

    # Silhouette (subsample para eficiencia)
    sil <- silhouette(km$cluster, dist(data_scaled[1:min(500, nrow(data_scaled)), ]))
    mlflow_log_metric("mean_silhouette", mean(sil[, 3]))

    # Artifacts: silhouette plot, cluster PCA plot
    # [código de plots omitido - ver scripts/clustering.R]

    mlflow_set_tag("chapter", "07-clustering")
  })

  invisible(list(km = km, k = k))
}

# Sweep de k para método del codo
run_kmeans_sweep <- function(data_scaled, k_range = 2:10) {
  purrr::map_dfr(k_range, function(k) {
    result <- run_kmeans(data_scaled, k = k)
    tibble(k = k, total_withinss = result$km$tot.withinss,
           bss_ratio = result$km$betweenss / result$km$totss)
  })
}

# Clustering jerárquico
run_hierarchical <- function(data_scaled, method = "ward.D2", k = 4) {
  with(mlflow_start_run(run_name = glue::glue("hclust_{method}_k{k}")), {
    mlflow_log_param("algorithm", "hierarchical")
    mlflow_log_param("linkage", method)
    mlflow_log_param("k", k)

    # Subsample si dataset grande
    idx <- sample(nrow(data_scaled), min(500, nrow(data_scaled)))
    subset <- data_scaled[idx, ]

    d <- dist(subset, method = "euclidean")
    hc <- hclust(d, method = method)
    cut <- cutree(hc, k = k)

    sil <- silhouette(cut, d)
    mlflow_log_metric("mean_silhouette", mean(sil[, 3]))

    # Artifact: dendrograma
    # [código de plot omitido - ver scripts/clustering.R]

    mlflow_set_tag("chapter", "07-clustering")
  })

  invisible(list(hc = hc, cut = cut))
}
```

### Uso en capítulos .qmd

**chapters/06-modeling.qmd**:

```r
source("../scripts/modeling.R")
ames <- readRDS("../data/ames_tf_generic.rds")
mlflow_set_experiment("ames-regression")

# Split
set.seed(2025)
split <- initial_split(ames, prop = 0.80, strata = Sale_Price)
train <- training(split)
test <- testing(split)
cv_folds <- vfold_cv(train, v = 10, strata = Sale_Price)

# Recipes
rec_base <- make_base_recipe(train)
rec_extended <- make_extended_recipe(train)

# Run models
lm_base <- run_model("linear_regression", rec_base, make_lm_spec(),
                     train, test, cv_folds, recipe_name = "base_recipe")

rf_base <- run_model("random_forest", rec_base, make_rf_spec(mtry = 10),
                     train, test, cv_folds, recipe_name = "base_recipe")

gbm_base <- run_model("gbm", rec_base, make_gbm_spec(trees = 500),
                      train, test, cv_folds, recipe_name = "base_recipe")

# Comparison table
comparison <- get_model_comparison_table("ames-regression")
comparison |> knitr::kable(digits = 4,
                            caption = "Comparación de modelos — métricas log10(Sale_Price)")
```

**chapters/07-clustering.qmd**:

```r
source("../scripts/clustering.R")
ames <- readRDS("../data/ames_tf_generic.rds")
mlflow_set_experiment("ames-clustering")

data_scaled <- make_cluster_data(ames)

# Método del codo
sweep_results <- run_kmeans_sweep(data_scaled, k_range = 2:10)

# Best k
km_final <- run_kmeans(data_scaled, k = 4)

# Jerárquico
hc_ward <- run_hierarchical(data_scaled, method = "ward.D2", k = 4)
```

### Modificaciones a setup.R

Agregar a `scripts/setup.R`:

```r
library(tidymodels)
library(mlflow)
library(carrier)    # model packaging
library(xgboost)    # GBM engine
library(ranger)     # RF engine
library(vip)        # variable importance plots
library(cluster)    # silhouette
library(factoextra) # cluster viz

conflicts_prefer(recipes::step_normalize, dplyr::select)
```

### Modificaciones a .gitignore

```
mlruns/
```

## Qué se registra

| Componente      | Regression                          | Clustering                        |
|-----------------|-------------------------------------|-----------------------------------|
| **Params**      | model, recipe, cv_folds, mtry, etc. | algorithm, k, nstart, linkage     |
| **Metrics (CV)**| cv_rmse_mean, cv_rsq_mean, cv_mae   | —                                 |
| **Metrics (Test)**| test_rmse, test_rsq, test_mae    | —                                 |
| **Metrics (Cluster)**| —                              | total_withinss, bss_tss_ratio, mean_silhouette |
| **Artifacts**   | workflow .rds, VIP plot, residual plot | cluster PCA plot, silhouette plot, dendrograma |
| **Tags**        | framework=tidymodels, dataset, chapter | chapter, algorithm              |

## Justificación

### Por qué MLflow vs alternativas

- **vs spreadsheets manuales**: automatización completa, trazabilidad, reproducibilidad
- **vs soluciones custom (tibbles con métricas)**: MLflow provee UI web, búsqueda, filtrado, ordenamiento, comparación lado a lado
- **vs frameworks específicos (neptune.ai, W&B)**: MLflow es open-source, local-first, sin vendor lock-in
- **vs no tracking**: auditoría de experimentos, comparación sistemática, recuperación de modelos/artifacts

### Por qué funciones en scripts/ en vez de inline en .qmd

Sigue el patrón del proyecto (ADR-005):
- **Funciones puras**: `run_model()` retorna list con workflow + métricas; MLflow logging es side-effect controlado dentro de `mlflow_start_run()`
- **Separación de concerns**: `.qmd` es narrativa, `scripts/` es implementación
- **Testabilidad**: las funciones son testeables de forma aislada
- **Reusabilidad**: `run_model()` se invoca 5+ veces con distintos specs sin duplicar código de logging

### Por qué dos experimentos separados

Regression y clustering tienen esquemas de métricas incompatibles:
- Regression: RMSE, R², MAE (métricas de predicción)
- Clustering: silhouette, WSS, BSS/TSS (métricas de calidad de agrupamiento)

Mezclarlos en un experimento produce columnas de métricas con NAs cruzados en el UI de MLflow, confundiendo la comparación.

### Por qué log CV + test metrics

- **CV metrics**: medida de generalización durante selección de modelo
- **Test metrics**: estimación insesgada final
- Loggear ambas permite detectar overfitting: gaps grandes entre `cv_rmse_mean` y `test_rmse` señalan que el modelo sobreajustó los folds de CV

## Consecuencias

### Positivas

- Comparación sistemática de modelos sin gestión manual
- Auditoría completa: ¿qué hiperparámetros, recipe, seed usó cada run?
- Recuperación de artifacts: cualquier workflow `.rds` puede recargarse desde MLflow sin re-fit
- UI web para exploración interactiva de resultados
- Reproducibilidad: cada run es una snapshot completa del experimento

### Negativas

- Dependencia adicional (`mlflow` package + Python backend)
- La carpeta `mlruns/` puede crecer (mitigable con cleanup periódico)
- MLflow logging agrega overhead (~2-5% tiempo de ejecución por run)

### Mitigación

- `mlruns/` en `.gitignore`: no commitear artifacts locales
- Para proyecto compartido (con Nahir): opción 1 = commit `mlruns/` si es pequeño, opción 2 = tracking server remoto
- Cleanup de runs viejos: `mlflow gc --backend-store-uri mlruns/`

## Visualización de resultados

Desde terminal en la raíz del proyecto:

```bash
Rscript -e "mlflow::mlflow_ui()"
# Abre http://localhost:5000
```

El UI muestra:
- Tabla de runs con métricas sorteable/filtrable
- Gráficos comparativos (scatter, parallel coords)
- Artifacts descargables (plots, workflows)
- Búsqueda por tags, params, fechas

## Referencias

- MLflow R package: https://mlflow.org/docs/latest/R-api.html
- tidymodels: https://www.tidymodels.org/
- Implementación completa: `scripts/modeling.R`, `scripts/clustering.R`
