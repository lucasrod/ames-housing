## ---- func-create-num-classification-table ----
#' Crear tabla de clasificación semántica de variables numéricas
#'
#' @param dict Data frame con el diccionario de variables 
#'   (columnas: variable, description, tipo_semantico)
#' @param data Data frame con los datos originales (e.g., ames_raw)
#' @param vars Vector opcional de nombres de variables numéricas a incluir;
#'   si es NULL se usan todas las detectadas automáticamente
#'
#' @return Tabla en formato kable con columnas:
#'   variable, description, tipo_semantico, clase, cardinalidad
#' @export
create_num_classification_table <- function(dict, data, vars = NULL) {
  # 1) Detectar todas las numéricas
  numeric_vars <- names(select(data, where(is.numeric)))
  # 2) Si el usuario pasó vars, filtrar
  if (!is.null(vars)) {
    numeric_vars <- intersect(numeric_vars, vars)
  }
  # 3) Construir tibble de clasificación
  numeric_classification <- tibble(
    variable     = numeric_vars,
    clase        = map_chr(variable, ~ class(data[[.x]])[1]),
    cardinalidad = map_int(variable, ~ n_distinct(data[[.x]], na.rm = TRUE))
  ) %>%
    left_join(dict, by = "variable") %>% 
    select(variable, description, tipo_semantico, clase, cardinalidad) %>%
    arrange(desc(cardinalidad))

  # 4) Devolver kable
  numeric_classification %>% kable()
}

## ---- func-create-cat-classification-table ----
#' Crear tabla de clasificación semántica de variables categóricas
#'
#' @param dict Data frame con el diccionario de variables 
#'   (columnas: variable, description, tipo_semantico)
#' @param skim_s Resultado de skimr::skim(data)
#' @param vars Vector opcional de nombres de variables categóricas a incluir;
#'   si es NULL se usan todas las detectadas automáticamente
#'
#' @return Tabla en formato kable con columnas:
#'   variable, description, tipo_semantico, n_levels, top_counts
#' @export
create_cat_classification_table <- function(dict, skim_s, vars = NULL) {
  # 1) Selección de factores, filtrando por vars si viene
  cat_s <- skim_s %>%
    filter(skim_type == "factor") %>%
    { if (!is.null(vars)) filter(., skim_variable %in% vars) else . }

  # 2) Construir tabla de clasificación
  cat_classification <- cat_s %>%
    select(
      variable   = skim_variable,
      n_levels   = factor.n_unique,
      top_counts = factor.top_counts
    ) %>%
    left_join(dict, by = "variable") %>%
    select(variable, description, tipo_semantico, n_levels, top_counts) %>%
    arrange(desc(n_levels))

  # 3) Devolver kable
  cat_classification %>% kable()
}

## ---- func-create-cat-levels-table ----
#' Crear tabla con niveles de variables categóricas
#'
#' @param dict Diccionario de variables (debe tener columnas: 
#'   variable, description, tipo_semantico)
#' @param skim_s Output del paquete `skimr::skim()` sobre el dataset
#' @param data Dataset original
#' @param vars Vector opcional de nombres de variables a incluir; si es NULL
#'   se usan todas las categóricas detectadas
#' @param top_n_levels Número de niveles principales a mostrar por variable;
#'   si es NULL, muestra todos los niveles
#'
#' @return Tabla en formato `kable` con columnas:
#'   variable, descripción, tipo_semántico, level, n, prop
#' @export
create_cat_levels_table <- function(dict, skim_s, data,
                                    vars = NULL,
                                    top_n_levels = NULL) {
  # 1) Determinar variables categóricas si no se especifican
  if (is.null(vars)) {
    vars <- skim_s %>%
      filter(skim_type == "factor") %>%
      pull(skim_variable)
  }

  # 2) Calcular cardinalidad de niveles
  cardinality <- skim_s %>%
    filter(skim_type == "factor", skim_variable %in% vars) %>%
    transmute(variable = skim_variable, n_levels = factor.n_unique)

  # 3) Calcular conteos y proporciones por nivel
  cat_levels <- purrr::map_dfr(vars, function(var) {
    data %>%
      count(level = .data[[var]], .drop = FALSE) %>%
      mutate(
        variable = var,
        prop     = scales::percent(n / sum(n), accuracy = 0.1)
      )
  })

  # 3b) Si top_n_levels está definido, quedarnos sólo con los n niveles más frecuentes
  if (!is.null(top_n_levels)) {
    cat_levels <- cat_levels %>%
      group_by(variable) %>%
      arrange(desc(n)) %>%
      slice_head(n = top_n_levels) %>%
      ungroup()
  }

  # 4) Unir con cardinalidad y diccionario, dar formato
  result <- cat_levels %>%
    left_join(cardinality, by = "variable") %>%
    left_join(dict,        by = "variable") %>%
    arrange(desc(n_levels), variable, desc(n)) %>%
    group_by(variable) %>%
    mutate(
      variable       = if_else(row_number() == 1, variable, ""),
      description    = if_else(row_number() == 1, description, ""),
      tipo_semantico = if_else(row_number() == 1, tipo_semantico, "")
    ) %>%
    ungroup() %>%
    select(variable, description, tipo_semantico, level, n, prop)

  # 5) Devolver tabla en formato kable
  result %>% kable()
}


## ---- func-create-cat-absence-table ----
#' Crear tabla de variables categóricas con niveles de ausencia estructural
#'
#' @param dict Data frame con el diccionario de variables 
#'   (columnas: variable, description, tipo_semantico)
#' @param data Data frame con los datos originales (e.g., ames_raw)
#' @param none_levels Vector de niveles que indican ausencia estructural. 
#'   Por defecto c("None","No_Alley_Access","No_Pool",
#'                 "No_Fence","No_Garage","No_Basement")
#' @param vars Vector opcional de nombres de variables categóricas a incluir;
#'   si es NULL se usan todas las que tengan al menos un nivel en none_levels
#'
#' @return Tabla en formato kable con columnas:
#'   variable, description, tipo_semantico, nivel_none, n_none, pct_none
#' @export
create_cat_absence_table <- function(dict, data,
                                     none_levels = c("None", "No_Alley_Access", "No_Pool",
                                                     "No_Fence", "No_Garage", "No_Basement"),
                                     vars = NULL) {
  n_obs <- nrow(data)
  
  # 1) Extraer sólo factores y pivotear
  abs_tbl <- data %>%
    select(where(is.factor)) %>%
    pivot_longer(everything(), 
                 names_to  = "variable", 
                 values_to = "value") %>%
    filter(value %in% none_levels) %>%           # quedamos sólo con los valores de ausencia
    group_by(variable) %>%
    summarise(
      n_none     = n(),                          # conteo de ocurrencias de ausencia
      nivel_none = paste(unique(value), collapse = ", "), # niveles usados
      .groups    = "drop"
    ) %>%
    filter(n_none > 0)                           # sólo variables con al menos un none
  
  # 2) Si se especifica un subset de vars, filtramos
  if (!is.null(vars)) {
    abs_tbl <- abs_tbl %>% filter(variable %in% vars)
  }
  
  # 3) Calcular proporción, unir diccionario y ordenar
  result <- abs_tbl %>%
    mutate(pct_none = scales::percent(n_none / n_obs, accuracy = 0.01)) %>%
    left_join(dict, by = "variable") %>%
    select(variable, description, tipo_semantico,
           nivel_none, n_none, pct_none) %>%
    arrange(desc(pct_none))
  
  # 4) Devolver kable
  result %>% kable()
}

## ---- func-create-zero-proportion-table ----
#' Crear tabla de proporción de ceros en variables numéricas
#'
#' @param dict Data frame con el diccionario de variables 
#'   (columnas: variable, description, tipo_semantico)
#' @param data Data frame con los datos originales (e.g., ames_raw)
#' @param top_n Número de variables con mayor proporción de ceros a mostrar;
#'   si es NULL, muestra todas las variables con al menos un cero
#'
#' @return Tabla en formato kable con columnas:
#'   variable, description, tipo_semantico, n_zero, pct_zero
#' @export
create_zero_proportion_table <- function(dict, data, top_n = NULL) {
  # Número de observaciones
  n_obs <- nrow(data)
  
  # 1) Seleccionar sólo variables numéricas
  num_df <- data %>% select(where(is.numeric))
  
  # 2) Calcular conteo y proporción de ceros
  zeros_tbl <- num_df %>%
    pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
    group_by(variable) %>%
    summarise(
      n_zero    = sum(value == 0, na.rm = TRUE),
      zero_prop = mean(value == 0, na.rm = TRUE),
      .groups   = "drop"
    ) %>%
    filter(n_zero > 0) %>%                # Sólo variables con al menos un cero
    arrange(desc(zero_prop))              # Orden descendente por proporción
  
  # 3) Si piden sólo un top_n, recortar
  if (!is.null(top_n)) {
    zeros_tbl <- zeros_tbl %>% slice_head(n = top_n)
  }
  
  # 4) Formatear proporción, unir diccionario y seleccionar columnas
  zeros_tbl %>%
    mutate(pct_zero = scales::percent(zero_prop, accuracy = 0.01)) %>%
    left_join(dict, by = "variable") %>%
    select(variable, description, tipo_semantico, n_zero, pct_zero) %>%
    kable()
}

## ---- func-create-absence-pair-table ----
#' Crear tabla de métricas de ausencia estructural por pares Cat/Num
#'
#' @param data Data frame con los datos originales (e.g., ames_raw)
#' @param pares Lista de vectores de longitud 2 con nombres de variables:
#'   el primer elemento es la variable categórica, el segundo es la variable numérica
#' @param none_levels Vector de niveles que indican ausencia estructural.
#'   Por defecto c("None", "No_Alley_Access", "No_Pool", "No_Fence", "No_Garage", "No_Basement")
#'
#' @return Tabla en formato kable con columnas:
#'   Var. Categ., Var. Num., count None, count 0,
#'   count None∧0, pct 0|None, pct None|0
#' @export
create_absence_pair_table <- function(data,
                                      pares,
                                      none_levels = c("None", "No_Alley_Access", "No_Pool",
                                                      "No_Fence", "No_Garage", "No_Basement")) {
  n_obs <- nrow(data)

  resumen_pareado <- function(par) {
    cat_var <- par[1]
    num_var <- par[2]

    df <- data %>%
      mutate(
        is_none = .data[[cat_var]] %in% none_levels,
        is_zero = .data[[num_var]] == 0
      )

    n_none      <- sum(df$is_none,    na.rm = TRUE)
    n_zero      <- sum(df$is_zero,    na.rm = TRUE)
    n_none_zero <- sum(df$is_none & df$is_zero, na.rm = TRUE)

    tibble(
      cat_var             = cat_var,
      num_var             = num_var,
      n_none              = n_none,
      n_zero              = n_zero,
      n_none_zero         = n_none_zero,
      pct_zero_given_none = if (n_none > 0) scales::percent(n_none_zero / n_none, accuracy = 0.1) else NA_real_,
      pct_none_given_zero = if (n_zero > 0) scales::percent(n_none_zero / n_zero, accuracy = 0.1) else NA_real_
    )
  }

  tabla <- purrr::map_dfr(pares, resumen_pareado)

  tabla %>%
    knitr::kable(
      col.names = c(
        "Var. Categ.", "Var. Num.",
        "count None", "count 0",
        "count None∧0",
        "pct 0|None", "pct None|0"
      )
    )
}

## ---- func-create-present-but-zero-table ----
#' Crear tabla resumida de discrepancias: presencia con valor cero
#'
#' @param data Data frame con los datos originales (e.g., ames_raw)
#' @param dict Data frame con el diccionario de variables (columnas: variable, description, tipo_semantico)
#' @param pares Lista de vectores de longitud 2 con nombres de variables:
#'   el primer elemento es la variable categórica, el segundo es la variable numérica
#' @param none_levels Vector de niveles que indican ausencia estructural.
#'   Por defecto c("None", "No_Alley_Access", "No_Pool",
#'                 "No_Fence", "No_Garage", "No_Basement")
#'
#' @return Tabla en formato kable con columnas:
#'   Pareja, Descripción categoría, Categoría discordante,
#'   Descripción numérica, Valor discordante
#' @export
create_present_but_zero_table <- function(data,
                                          dict,
                                          pares,
                                          none_levels = c("None", "No_Alley_Access", "No_Pool",
                                                          "No_Fence", "No_Garage", "No_Basement")) {
  tbl <- purrr::map_dfr(pares, function(par) {
    cat_var <- par[1]
    num_var <- par[2]
    desc_cat <- dict %>% filter(variable == cat_var) %>% pull(description)
    desc_num <- dict %>% filter(variable == num_var) %>% pull(description)
    data %>%
      filter(
        !(.data[[cat_var]] %in% none_levels) &
          .data[[num_var]] == 0
      ) %>%
      transmute(
        Pareja                   = paste(cat_var, "vs", num_var),
        `Descripción categoría`   = desc_cat,
        `Categoría discordante`   = as.character(.data[[cat_var]]),
        `Descripción numérica`    = desc_num,
        `Valor discordante`       = .data[[num_var]]
      )
  })

  kable(tbl)
}

## ---- func-create-absent-but-positive-table ----
#' Crear tabla resumida de discrepancias: ausencia con valor positivo
#'
#' @param data Data frame con los datos originales (e.g., ames_raw)
#' @param dict Data frame con el diccionario de variables (columnas: variable, description, tipo_semantico)
#' @param pares Lista de vectores de longitud 2 con nombres de variables:
#'   el primer elemento es la variable categórica, el segundo es la variable numérica
#' @param none_levels Vector de niveles que indican ausencia estructural.
#'   Por defecto c("None", "No_Alley_Access", "No_Pool",
#'                 "No_Fence", "No_Garage", "No_Basement")
#'
#' @return Tabla en formato kable con columnas:
#'   Pareja, Descripción categoría, Categoría discordante,
#'   Descripción numérica, Valor discordante
#' @export
create_absent_but_positive_table <- function(data,
                                             dict,
                                             pares,
                                             none_levels = c("None", "No_Alley_Access", "No_Pool",
                                                             "No_Fence", "No_Garage", "No_Basement")) {
  tbl <- purrr::map_dfr(pares, function(par) {
    cat_var <- par[1]
    num_var <- par[2]
    desc_cat <- dict %>% filter(variable == cat_var) %>% pull(description)
    desc_num <- dict %>% filter(variable == num_var) %>% pull(description)
    data %>%
      filter(
        (.data[[cat_var]] %in% none_levels) &
          .data[[num_var]] > 0
      ) %>%
      transmute(
        Pareja                   = paste(cat_var, "vs", num_var),
        `Descripción categoría`   = desc_cat,
        `Categoría discordante`   = as.character(.data[[cat_var]]),
        `Descripción numérica`    = desc_num,
        `Valor discordante`       = .data[[num_var]]
      )
  })

  kable(tbl)
}

