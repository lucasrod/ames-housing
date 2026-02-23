# ../scripts/transformations.R
# ------------------------------------------------------------------
#
# Todas las funciones son puras: toman un data.frame/tibble y
# devuelven uno nuevo (sin modificar el original). Cada función
# agrega metadatos en el atributo "transform_log" para trazabilidad.
# ------------------------------------------------------------------

## ---- drop-outliers-grlivarea ----
## -----------------------------------------------------------------
## 1. Filtro opcional de outliers por área habitable sobre nivel
##    del suelo (Gr_Liv_Area > cutoff)
##    Recomendado por De Cock: remover >4000 sq ft. 
## -----------------------------------------------------------------
drop_outliers_grlivarea <- function(data, cutoff = 4000, col = "Gr_Liv_Area") {
  stopifnot(col %in% names(data))
  n_before <- nrow(data)
  data2 <- data %>% filter(.data[[col]] <= cutoff | is.na(.data[[col]]))
  n_drop <- n_before - nrow(data2)
  data2 <- .add_log(
    data2,
    "drop_outliers_grlivarea",
    sprintf("Removed %s rows where %s > %s", n_drop, col, cutoff)
  )
  attr(data2, "dropped_grlivarea_rows") <- n_drop
  data2
}

## ---- subset-for-intro ----
## -----------------------------------------------------------------
## 2. Subconjunto para cursos introductorios:
##    - Mantener sólo ventas 'Normal' (Sale_Condition)
##    - Opción de restringir a viviendas pequeñas (max_area)
##    - Útil para ejemplos con varianza más homogénea.
## -----------------------------------------------------------------
subset_for_intro <- function(data,
                             sale_condition_col = "Sale_Condition",
                             keep_normal = TRUE,
                             max_area = 1500,
                             area_col = "Gr_Liv_Area") {
  data2 <- data
  if (keep_normal && sale_condition_col %in% names(data2)) {
    data2 <- data2 %>% filter(.data[[sale_condition_col]] == "Normal")
  }
  if (!is.null(max_area) && area_col %in% names(data2)) {
    data2 <- data2 %>% filter(.data[[area_col]] <= max_area | is.na(.data[[area_col]]))
  }
  data2 <- .add_log(
    data2,
    "subset_for_intro",
    sprintf("keep_normal=%s, max_area=%s", keep_normal, max_area)
  )
  data2
}

## ---- add-total-sqft ----
## -----------------------------------------------------------------
## 3. Total de superficie habitable: bsmt + sobre nivel
##    De Cock usa 'TOTAL BSMT SF + GR LIV AREA' como predictor clave.
## -----------------------------------------------------------------
add_total_sqft <- function(data,
                           bsmt = "Total_Bsmt_SF",
                           gr   = "Gr_Liv_Area",
                           new  = "Total_SqFt") {
  stopifnot(bsmt %in% names(data), gr %in% names(data))
  data2 <- mutate(data, !!new := .data[[bsmt]] + .data[[gr]])
  data2 <- .add_log(
    data2,
    "add_total_sqft",
    sprintf("%s = %s + %s", new, bsmt, gr)
  )
  data2
}

## ---- add-fire-yn ----
## -----------------------------------------------------------------
## 4. Indicador de chimenea: FireYN (1 si Fireplaces > 0)
##    Ejemplo didáctico de De Cock al mostrar un modelo mixto.
## -----------------------------------------------------------------
add_fire_yn <- function(data,
                        fire_col = "Fireplaces",
                        new = "FireYN") {
  stopifnot(fire_col %in% names(data))
  data2 <- mutate(
    data,
    !!new := factor(if_else(.data[[fire_col]] > 0, 1L, 0L),
                    levels = c(0L, 1L),
                    labels = c("No", "Yes"))
  )
  data2 <- .add_log(data2, "add_fire_yn", sprintf("%s = 1 if %s>0", new, fire_col))
  data2
}

## ---- add-has-indicators ----
## -----------------------------------------------------------------
## 5. Creación de indicadores binarios de presencia/ausencia
##    a partir de niveles "ausencia" en variables categóricas.
##    Usa vector none_levels: e.g. c('None','No_Garage','No_Basement',...)
## -----------------------------------------------------------------
add_has_indicators <- function(data, vars, none_levels,
                               prefix = "has_",
                               lowercase = TRUE) {
  stopifnot(all(vars %in% names(data)))
  data2 <- data
  log_rows <- vector("list", length(vars))
  for (i in seq_along(vars)) {
    v <- vars[[i]]
    nm <- if (lowercase) tolower(v) else v
    new_nm <- paste0(prefix, nm)
    vals <- as.integer(! (data2[[v]] %in% none_levels))
    data2[[new_nm]] <- vals
    log_rows[[i]] <- tibble(step = paste0("add_has_", v),
                            detail = sprintf("%s = 1 if %s not in none_levels", new_nm, v))
  }
  # anexar log
  log_tbl <- bind_rows(log_rows)
  old_log <- attr(data2, "transform_log")
  if (is.null(old_log)) old_log <- tibble(step = character(), detail = character())
  attr(data2, "transform_log") <- bind_rows(old_log, log_tbl)
  data2
}

## ---- collapse-levels ----
## -----------------------------------------------------------------
## 6. Colapsar niveles de una variable ordinal.
##    mapping: named vector (new_level -> c(old1, old2, ...)) o
##    named list. Devuelve factor con los nuevos niveles.
## -----------------------------------------------------------------
collapse_levels <- function(data, var, mapping, new = paste0(var, "_grp"),
                            other_level = "Other") {
  stopifnot(var %in% names(data))
  x <- as.character(data[[var]])
  # construir tabla de recodificación
  recode_map <- rep(names(mapping), lengths(mapping))
  names(recode_map) <- unlist(mapping, use.names = FALSE)
  # asignar
  x_new <- recode(x, !!!recode_map, .default = other_level, .missing = other_level)
  data2 <- mutate(data, !!new := factor(x_new, levels = unique(c(names(mapping), other_level))))
  data2 <- .add_log(
    data2, "collapse_levels",
    sprintf("%s collapsed to %s via mapping (%s groups + %s)", var, new, length(mapping), other_level)
  )
  data2
}

## ---- force-baselines-first ----
## -----------------------------------------------------------------
## 7. Reordenar niveles para fijar baseline
## -----------------------------------------------------------------
force_baselines_first <- function(data, vars, baseline_map = NULL) {
  stopifnot(all(vars %in% names(data)))
  df <- data
  
  for (var in vars) {
    f <- df[[var]]
    if (!is.factor(f)) {
      warning(sprintf("'%s' no es factor; lo convierto a factor.", var))
      f <- factor(f)
    }
    # determinar baseline: mapeado o nivel más frecuente
    if (!is.null(baseline_map) && var %in% names(baseline_map)) {
      lvl <- baseline_map[[var]]
      if (!lvl %in% levels(f)) {
        stop(sprintf("'%s' no es nivel de %s", lvl, var))
      }
    } else {
      # fallback: el nivel con mayor conteo
      lvl <- names(sort(table(f), decreasing = TRUE))[1]
    }
    # relevel para que 'lvl' quede primero
    df[[var]] <- fct_relevel(f, lvl, after = 0)
  }

  df
}

## ---- apply-power-transforms ----
## -----------------------------------------------------------------
## 8. Transformaciones de potencia seguras (log, sqrt, inv, square)
##    - respeta NAs
##    - no transforma valores <= 0 para log/inv; devuelve NA
##    spec: named list var = c('log','sqrt',...)
## -----------------------------------------------------------------
apply_power_transforms <- function(data, spec, suffix = "_tr") {
  data2 <- data
  logs <- vector("list", length(spec))
  i <- 0L
  for (nm in names(spec)) {
    funs <- spec[[nm]]
    if (!nm %in% names(data2)) next
    for (f in funs) {
      i <- i + 1L
      new_nm <- paste0(nm, "_", f, suffix)
      vals <- data2[[nm]]
      if (f == "log") {
        vals <- ifelse(vals > 0, log(vals), NA_real_)
      } else if (f == "sqrt") {
        vals <- ifelse(vals >= 0, sqrt(vals), NA_real_)
      } else if (f == "inv") {
        vals <- ifelse(vals != 0, 1/vals, NA_real_)
      } else if (f == "sq") {
        vals <- vals^2
      } else {
        stop("Unsupported transform: ", f)
      }
      data2[[new_nm]] <- vals
      logs[[i]] <- tibble(
        step = paste0("apply_", f),
        detail = sprintf("%s -> %s", nm, new_nm)
      )
    }
  }
  old_log <- attr(data2, "transform_log")
  if (is.null(old_log)) old_log <- tibble(step = character(), detail = character())
  attr(data2, "transform_log") <- bind_rows(old_log, bind_rows(logs))
  data2
}

## ---- transform-generic-ames ----
## -----------------------------------------------------------------
## 9. Pipeline maestro genérico
##    Se ejecuta en orden lógico sobre el objeto limpio resultante
##    de la fase de limpieza (ames_clean).
##    Parámetros controlan pasos opcionales.
## -----------------------------------------------------------------
transform_generic_ames <- function(data,
                                   filter_outliers = TRUE,
                                   cutoff = 4000,
                                   intro_subset = FALSE,
                                   keep_normal = TRUE,
                                   max_area = 1500,
                                   none_levels = c("None","No_Alley_Access",
                                                   "No_Pool","No_Fence",
                                                   "No_Garage","No_Basement"),
                                   has_vars = c("Pool_QC","Mas_Vnr_Type",
                                                "Garage_Cond","Bsmt_Cond",
                                                "Fence","Alley"),
                                   collapse_list = NULL,
                                   power_spec = NULL) {

  d <- data

  if (filter_outliers) {
    d <- drop_outliers_grlivarea(d, cutoff = cutoff)
  }

  if (intro_subset) {
    d <- subset_for_intro(d,
                          keep_normal = keep_normal,
                          max_area = max_area)
  }

  d <- add_total_sqft(d)
  d <- add_fire_yn(d)

  if (!is.null(has_vars)) {
    d <- add_has_indicators(d, vars = has_vars, none_levels = none_levels)
  }

  if (!is.null(collapse_list)) {
    for (v in names(collapse_list)) {
      d <- collapse_levels(d, v, mapping = collapse_list[[v]])
    }
  }

  if (!is.null(power_spec)) {
    d <- apply_power_transforms(d, spec = power_spec)
  }

  d
}
