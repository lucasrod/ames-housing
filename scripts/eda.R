## ---- func-compute-summary-stats ----
#' Calcular estadísticos descriptivos para variables numéricas
#'
#' Función pura: recibe data frame + vector de nombres, devuelve tibble.
#' Usa `e1071::skewness()` y `e1071::kurtosis()` para momentos de orden superior.
#'
#' @param data Data frame con los datos.
#' @param vars Character vector de nombres de variables numéricas a resumir.
#'   Si es `NULL`, se usan todas las numéricas detectadas con `where(is.numeric)`.
#'
#' @return Tibble con columnas: variable, n, n_na, mean, sd, median,
#'   q25, q75, min, max, skewness, kurtosis. Siempre devuelve tibble
#'   (type-stable) incluso con un solo var.
compute_summary_stats <- function(data, vars = NULL) {
  stopifnot(is.data.frame(data))

  if (is.null(vars)) {
    vars <- names(dplyr::select(data, where(is.numeric)))
  }
  stopifnot(is.character(vars), length(vars) >= 1)

  purrr::map_dfr(vars, function(v) {
    x <- data[[v]]
    x_clean <- x[!is.na(x)]
    tibble::tibble(
      variable = v,
      n        = length(x_clean),
      n_na     = sum(is.na(x)),
      mean     = mean(x_clean),
      sd       = sd(x_clean),
      median   = median(x_clean),
      q25      = quantile(x_clean, 0.25, names = FALSE),
      q75      = quantile(x_clean, 0.75, names = FALSE),
      min      = min(x_clean),
      max      = max(x_clean),
      skewness = e1071::skewness(x_clean),
      kurtosis = e1071::kurtosis(x_clean)
    )
  })
}

## ---- func-filter-top-neighborhoods ----
#' Filtrar datos a los top N barrios por frecuencia
#'
#' @param data Data frame con columna `Neighborhood` (factor).
#' @param n Número de barrios a conservar (default 15).
#'
#' @return Data frame filtrado con `Neighborhood` re-nivelado (drop unused levels).
#'   Mismas columnas que input (type-stable).
filter_top_neighborhoods <- function(data, n = 15) {
  stopifnot("Neighborhood" %in% names(data), is.numeric(n), n >= 1)

  top_names <- data %>%
    dplyr::count(.data[["Neighborhood"]], sort = TRUE) %>%
    dplyr::slice_head(n = n) %>%
    dplyr::pull(.data[["Neighborhood"]])

  data %>%
    dplyr::filter(.data[["Neighborhood"]] %in% top_names) %>%
    dplyr::mutate(Neighborhood = forcats::fct_drop(.data[["Neighborhood"]]))
}

## ---- func-plot-scatter-vs-price ----
#' Crear scatter plot de una variable numérica vs Sale_Price
#'
#' Usa `.data[[var]]` (tidy evaluation, patrón names) para selección
#' segura de columnas por string. Retorna ggplot para composición con `+` o patchwork.
#'
#' @param data Data frame con columnas `Sale_Price` y la columna indicada en `x_var`.
#' @param x_var Character escalar: nombre de la variable para el eje x.
#' @param log_y Logical; si `TRUE` (default) aplica `scale_y_log10()`.
#' @param smooth Logical; si `TRUE` (default) agrega curva loess.
#' @param x_label Character escalar opcional para etiqueta del eje x.
#'   Si `NULL` (default), usa `x_var`.
#'
#' @return Objeto ggplot (type-stable).
plot_scatter_vs_price <- function(data, x_var, log_y = TRUE, smooth = TRUE,
                                  x_label = NULL) {
  stopifnot(
    is.data.frame(data),
    is.character(x_var), length(x_var) == 1,
    x_var %in% names(data),
    "Sale_Price" %in% names(data)
  )
  if (is.null(x_label)) x_label <- x_var

  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data[[x_var]], y = .data[["Sale_Price"]])) +
    ggplot2::geom_point(alpha = 0.3, size = 1, color = "grey30") +
    ggplot2::labs(x = x_label, y = "Precio de venta (USD)")

  if (smooth) {
    p <- p + ggplot2::geom_smooth(
      method = "loess", formula = y ~ x,
      se = FALSE, color = "#E69F00", linewidth = 1
    )
  }
  if (log_y) {
    p <- p + ggplot2::scale_y_log10(labels = scales::dollar_format())
  } else {
    p <- p + ggplot2::scale_y_continuous(labels = scales::dollar_format())
  }

  p + ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

## ---- func-plot-boxplot-vs-price ----
#' Crear boxplot de Sale_Price por una variable categórica
#'
#' @param data Data frame con `Sale_Price` y `cat_var`.
#' @param cat_var Character escalar: nombre de la variable categórica.
#' @param log_y Logical; si `TRUE` (default) aplica `scale_y_log10()`.
#' @param reorder Logical; si `TRUE` (default) reordena niveles por mediana de Sale_Price.
#' @param x_label Character escalar opcional para etiqueta del eje categórico.
#'
#' @return Objeto ggplot (type-stable).
plot_boxplot_vs_price <- function(data, cat_var, log_y = TRUE, reorder = TRUE,
                                  x_label = NULL) {
  stopifnot(
    is.data.frame(data),
    is.character(cat_var), length(cat_var) == 1,
    cat_var %in% names(data),
    "Sale_Price" %in% names(data)
  )
  if (is.null(x_label)) x_label <- cat_var

  if (reorder) {
    data <- data %>%
      dplyr::mutate(
        !!cat_var := forcats::fct_reorder(.data[[cat_var]], .data[["Sale_Price"]], .fun = median)
      )
  }

  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data[[cat_var]], y = .data[["Sale_Price"]])) +
    ggplot2::geom_boxplot(fill = "#56B4E9", alpha = 0.7, outlier.alpha = 0.3) +
    ggplot2::labs(x = x_label, y = "Precio de venta (USD)") +
    ggplot2::coord_flip()

  if (log_y) {
    p <- p + ggplot2::scale_y_log10(labels = scales::dollar_format())
  } else {
    p <- p + ggplot2::scale_y_continuous(labels = scales::dollar_format())
  }

  p + ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

## ---- func-compute-cor-matrix ----
#' Calcular matriz de correlación para variables seleccionadas
#'
#' Usa `all_of()` (tidy-select) para selección segura por character vector.
#'
#' @param data Data frame.
#' @param vars Character vector de nombres de variables numéricas.
#'
#' @return Matriz de correlación (clase `matrix`, type-stable).
compute_cor_matrix <- function(data, vars) {
  stopifnot(is.data.frame(data), is.character(vars))
  stopifnot(all(vars %in% names(data)))

  data %>%
    dplyr::select(dplyr::all_of(vars)) %>%
    stats::cor(use = "pairwise.complete.obs")
}

## ---- func-plot-violin-vs-price ----
#' Crear violin plot de Sale_Price por una variable categórica
#'
#' Combina `geom_violin()` + `geom_boxplot()` interior para mostrar
#' tanto la densidad como los cuartiles. Patrón `.data[[var]]` para
#' selección por string.
#'
#' @param data Data frame con `Sale_Price` y `cat_var`.
#' @param cat_var Character escalar: nombre de la variable categórica.
#' @param log_y Logical; si `TRUE` (default) aplica `scale_y_log10()`.
#' @param reorder Logical; si `TRUE` (default) reordena niveles por mediana.
#' @param x_label Character escalar opcional para etiqueta del eje categórico.
#'
#' @return Objeto ggplot (type-stable).
plot_violin_vs_price <- function(data, cat_var, log_y = TRUE, reorder = TRUE,
                                 x_label = NULL) {
  stopifnot(
    is.data.frame(data),
    is.character(cat_var), length(cat_var) == 1,
    cat_var %in% names(data),
    "Sale_Price" %in% names(data)
  )
  if (is.null(x_label)) x_label <- cat_var

  if (reorder) {
    data <- data %>%
      dplyr::mutate(
        !!cat_var := forcats::fct_reorder(.data[[cat_var]], .data[["Sale_Price"]], .fun = median)
      )
  }

  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data[[cat_var]], y = .data[["Sale_Price"]])) +
    ggplot2::geom_violin(fill = "#56B4E9", alpha = 0.6, color = "grey30") +
    ggplot2::geom_boxplot(width = 0.15, fill = "white", alpha = 0.8, outlier.shape = NA) +
    ggplot2::labs(x = x_label, y = "Precio de venta (USD)") +
    ggplot2::coord_flip()

  if (log_y) {
    p <- p + ggplot2::scale_y_log10(labels = scales::dollar_format())
  } else {
    p <- p + ggplot2::scale_y_continuous(labels = scales::dollar_format())
  }

  p + ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

## ---- func-lookup-var-label ----
#' Buscar la descripción en español de una variable en el diccionario
#'
#' Función de lookup pura. Para variables derivadas no presentes en el
#' diccionario, usa un fallback hardcodeado.
#'
#' @param var Character escalar: nombre de la variable.
#' @param dict Data frame con columnas `variable` y `description`.
#'
#' @return Character escalar con la descripción en español (type-stable).
lookup_var_label <- function(var, dict) {
  stopifnot(is.character(var), length(var) == 1)

  fallback <- c(
    Total_SqFt         = "Superficie total (pies\u00b2)",
    FireYN             = "\u00bfTiene chimenea?",
    has_pool_qc        = "\u00bfTiene piscina?",
    has_fence          = "\u00bfTiene cerco?",
    has_second_flr_sf  = "\u00bfTiene segundo piso?",
    has_fireplaces     = "\u00bfTiene chimenea?",
    has_mas_vnr_type   = "\u00bfTiene revestimiento?",
    has_garage_cond    = "\u00bfTiene garaje?",
    has_bsmt_cond      = "\u00bfTiene s\u00f3tano?",
    has_alley          = "\u00bfTiene acceso por callej\u00f3n?",
    Sale_Price_log_tr  = "log(Precio de venta)",
    Total_SqFt_log_tr  = "log(Superficie total)",
    Total_SqFt_sq_tr   = "Superficie total\u00b2",
    Gr_Liv_Area_sqrt_tr = "\u221a(Área habitable)",
    Lot_Area_log_tr    = "log(Área del terreno)"
  )

  desc <- dict[dict$variable == var, "description", drop = TRUE]
  if (length(desc) == 1 && !is.na(desc)) return(desc)
  if (var %in% names(fallback)) return(fallback[[var]])
  var
}
