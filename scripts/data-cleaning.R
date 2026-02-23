## ---- convert-structural-zeros ----
#' Convertir ceros estructurales a NA y registrar la conversión
#'
#' @description
#'   Detecta todas las variables numéricas que usan 0 como ausencia estructural
#'   (tienen al menos un 0) y convierte esos ceros en NA.  
#'   Además, registra cuántos ceros se convirtieron por variable.
#'
#' @param data Tibble o data.frame con las variables originales.
#' @param zero_vars Vector de nombres de variables numéricas; si es NULL,
#'   detecta automáticamente las que contienen al menos un 0.
#' @param verbose Lógico; si `TRUE`, imprime en consola cuántos ceros se
#'   convirtieron por variable y devuelve una lista con el resumen.
#'
#' @return
#'   - Si `verbose = FALSE`: un `tibble` con los ceros transformados
#'     en NA y con un _atributo_ `"zero_summary"` (un tibble
#'     con las columnas `variable` y `n_converted`).  
#'   - Si `verbose = TRUE`: una `list` con dos elementos:
#'     * `data`: el `tibble` recodificado  
#'     * `summary`: el `tibble` de conversiones
#' @export
convert_structural_zeros_to_na <- function(data, zero_vars = NULL, verbose = FALSE) {
  # validaciones básicas
  stopifnot(is.data.frame(data), is.null(zero_vars) || is.character(zero_vars), is.logical(verbose))

  # detectar zero_vars si no se pasan
  if (is.null(zero_vars)) {
    zero_vars <- data %>%
      dplyr::select(dplyr::where(is.numeric)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ any(. == 0, na.rm = TRUE))) %>%
      tidyr::pivot_longer(
        cols      = dplyr::everything(),
        names_to  = "variable",
        values_to = "has_zero"
      ) %>%
      dplyr::filter(has_zero) %>%
      dplyr::pull(variable)
  }

  # inicializar log
  conversion_log <- tibble::tibble(
    variable    = character(),
    n_converted = integer()
  )

  # contar y (opcionalmente) notificar
  for (var in zero_vars) {
    n0 <- sum(data[[var]] == 0, na.rm = TRUE)
    if (verbose && n0 > 0) {
      message(sprintf("Convertir %d ceros en '%s' a NA", n0, var))
    }
    conversion_log <- dplyr::bind_rows(
      conversion_log,
      tibble::tibble(variable = var, n_converted = n0)
    )
  }

  # hacer la conversión
  data_recoded <- data %>%
    dplyr::mutate(dplyr::across(dplyr::all_of(zero_vars), ~ dplyr::na_if(., 0)))

  # devolver según verbose
  if (verbose) {
    return(list(data = data_recoded, summary = conversion_log))
  } else {
    attr(data_recoded, "zero_summary") <- conversion_log
    return(data_recoded)
  }
}


## ---- recode-categorical-absence ----
#' Recodifica ausencias estructurales de variables categóricas
#'
#' @description
#' Para cada par (variable categórica, variable numérica):
#' - Si la categoría indica **ausencia** (niveles en `none_levels`)
#'   pero el valor numérico > 0, recodifica la variable categórica
#'   a su **moda** (excluyendo niveles de ausencia).  
#' También registra cuántas observaciones se recodificaron por variable
#' y a qué nivel.
#'
#' @param data Un `data.frame` o `tibble` con las variables originales.
#' @param pairs Lista de vectores de longitud 2 con nombres de variables:
#'   * primer elemento: nombre de la variable **categórica**  
#'   * segundo elemento: nombre de la variable **numérica** asociada  
#' @param none_levels Character vector con los niveles que indican **ausencia**.
#' @param verbose Lógico; si `TRUE`, imprime en consola cuántas recodificaciones
#'   se hicieron por variable.  
#' @return Si `verbose = FALSE`, un `tibble` recodificado con un _atributo_
#'   `"recode_summary"` (un `tibble` con el conteo de recodificaciones).  
#'   Si `verbose = TRUE`, una `list` con dos elementos:
#'   * `data`: el `tibble` recodificado  
#'   * `summary`: el `tibble` de recodificaciones  
#' @export
recode_categorical_absence <- function(data, pairs, none_levels, verbose = FALSE) {
  stopifnot(is.data.frame(data), is.list(pairs), is.character(none_levels), is.logical(verbose))
  data_recoded <- data
  # inicializar log
  recode_log <- tibble::tibble(
    variable   = character(),
    n_recoded  = integer(),
    new_level  = character()
  )
  
  for (pair in pairs) {
    cat_var <- pair[[1]]
    num_var <- pair[[2]]
    
    # calcular moda excluyendo niveles de ausencia
    moda_cat <- data_recoded %>%
      dplyr::filter(!(.data[[cat_var]] %in% none_levels)) %>%
      dplyr::count(.data[[cat_var]], sort = TRUE) %>%
      dplyr::slice(1) %>%
      dplyr::pull(.data[[cat_var]])
    
    # cuántas filas cumplen la condición de recodificar
    condicion <- data_recoded[[cat_var]] %in% none_levels & data_recoded[[num_var]] > 0
    n_recod  <- sum(condicion, na.rm = TRUE)
    
    # mensaje en consola si verbose
    if (verbose && n_recod > 0) {
      message(sprintf(
        "Recodificando %d observaciones de '%s' a nivel '%s'",
        n_recod, cat_var, moda_cat
      ))
    }
    
    # agregar al log
    recode_log <- dplyr::bind_rows(
      recode_log,
      tibble::tibble(
        variable  = cat_var,
        n_recoded = n_recod,
        new_level = moda_cat
      )
    )
    
    # hacer la recodificación
    data_recoded <- data_recoded %>%
      dplyr::mutate(
        !!cat_var := dplyr::case_when(
          condicion ~ moda_cat,
          TRUE      ~ .data[[cat_var]]
        )
      )
  }
  
  if (verbose) {
    return(list(data = data_recoded, summary = recode_log))
  } else {
    # adjuntar el resumen como atributo
    attr(data_recoded, "recode_summary") <- recode_log
    return(data_recoded)
  }
}


## ---- create-has-indicators ----
#' Crea indicadores binarios 'has_<variable>' según niveles de ausencia
#'
#' @description
#'   A partir de un vector de variables categóricas, genera para cada una
#'   una columna indicadora `has_<variable>` (0/1), donde 1 = categoría **no**
#'   está en `none_levels`.  
#'   Además registra cuántas observaciones tienen valor 1 para cada indicador.
#'
#' @param data Un `data.frame` o `tibble` con las variables originales.
#' @param cat_vars Vector de caracteres con los nombres de las variables categóricas.
#' @param none_levels Vector de caracteres con los niveles que indican **ausencia**.
#' @param verbose Lógico; si `TRUE`, imprime en consola cuántos 1 generó cada indicador
#'   y devuelve una lista con `$data` y `$summary`.  
#'   Si `FALSE` (por defecto), devuelve solo el `tibble` y deja el resumen como atributo.
#'
#' @return
#' - Si `verbose = FALSE`: un `tibble` con las nuevas columnas `has_<variable>`,
#'   y atributo `"has_summary"` (un `tibble` con `variable` y `n_has`).  
#' - Si `verbose = TRUE`: una `list` con dos elementos:
#'   * `data`: el `tibble` ampliado  
#'   * `summary`: el `tibble` resumen de conteos  
#'
#' @export
create_has_indicators <- function(data, cat_vars, none_levels, verbose = FALSE) {
  stopifnot(
    is.data.frame(data),
    is.character(cat_vars),
    is.character(none_levels),
    is.logical(verbose)
  )
  data_ind   <- data
  has_log    <- tibble::tibble(variable = character(), n_has = integer())
  
  for (cat_var in cat_vars) {
    new_col <- paste0("has_", tolower(cat_var))
    
    # vector de 0/1
    vals   <- as.integer(! (data_ind[[cat_var]] %in% none_levels))
    n_has  <- sum(vals, na.rm = TRUE)
    
    # mensaje si verbose
    if (verbose && n_has > 0) {
      message(sprintf(
        "Indicador '%s': %d observaciones = 1",
        new_col, n_has
      ))
    }
    
    # agrego al log
    has_log <- dplyr::bind_rows(
      has_log,
      tibble::tibble(variable = new_col, n_has = n_has)
    )
    
    # incorporo la columna al data frame
    data_ind[[new_col]] <- vals
  }
  
  if (verbose) {
    return(list(data = data_ind, summary = has_log))
  } else {
    attr(data_ind, "has_summary") <- has_log
    return(data_ind)
  }
}

## ---- create-has-num-indicators -------------------------------------------
#' Crea indicadores binarios 'has_<variable>' a partir de numéricas
#'
#' @description
#'   Para cada variable numérica de `num_vars` genera `has_<var>` (0/1):
#'   1 si el valor es > `threshold` y no es NA; 0 en caso contrario.
#'   Registra cuántas observaciones tienen 1.
#'
#' @param data      data.frame / tibble origen
#' @param num_vars  character(), nombres de variables numéricas
#' @param threshold valor de corte (default 0)
#' @param verbose   imprime conteos si TRUE
#'
#' @return
#'   - Si verbose = FALSE: tibble con atributo "has_num_summary"
#'   - Si verbose = TRUE:  list(data, summary)
#' @export
create_has_num_indicators <- function(data,
                                      num_vars,
                                      threshold = 0,
                                      verbose   = FALSE) {
  stopifnot(is.data.frame(data),
            is.character(num_vars),
            is.numeric(threshold),
            is.logical(verbose))

  data_ind <- data
  has_log  <- tibble::tibble(variable = character(), n_has = integer())

  for (num_var in num_vars) {
    new_col <- paste0("has_", tolower(num_var))
    vals    <- as.integer(!is.na(data_ind[[num_var]]) &
                            data_ind[[num_var]] > threshold)
    n_has   <- sum(vals, na.rm = TRUE)

    if (verbose) message(sprintf("Indicador '%s': %d casos = 1", new_col, n_has))

    has_log <- dplyr::bind_rows(has_log,
                                tibble::tibble(variable = new_col, n_has = n_has))
    data_ind[[new_col]] <- vals
  }

  if (verbose) {
    list(data = data_ind, summary = has_log)
  } else {
    attr(data_ind, "has_num_summary") <- has_log
    data_ind
  }
}
