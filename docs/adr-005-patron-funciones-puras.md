# ADR-005: Patron de funciones puras con trazabilidad por atributos

**Estado**: Aceptada
**Fecha**: 2025-07-05
**Scripts relacionados**: scripts/data-cleaning.R, scripts/transformations.R

## Contexto

El pipeline de datos requiere multiples pasos de limpieza y transformacion encadenados. Se necesitaba un patron de diseno que garantizara:
- Reproducibilidad: el mismo input produce el mismo output.
- Trazabilidad: poder auditar que transformaciones se aplicaron y cuantos registros afectaron.
- Composibilidad: las funciones deben poder encadenarse libremente.
- Testabilidad: cada funcion debe poder probarse de manera aislada.

## Decision

Todas las funciones de limpieza y transformacion siguen este patron:

1. **Funciones puras**: reciben un data.frame y parametros, devuelven un data.frame nuevo sin modificar el original (sin side-effects).
2. **Trazabilidad via atributos R**: cada funcion adjunta metadatos al output usando `attr()`. Los atributos tipicos son:
   - `"zero_summary"`: conteo de ceros convertidos por variable
   - `"recode_summary"`: conteo y nivel de recodificaciones
   - `"has_summary"` / `"has_num_summary"`: conteo de indicadores creados
   - `"transform_log"`: tibble con `step` y `detail` para cada transformacion
3. **Parametro `verbose`**: controla el comportamiento de retorno:
   - `verbose = FALSE` (default): retorna tibble con atributo adjunto
   - `verbose = TRUE`: retorna `list(data = tibble, summary = tibble)` e imprime mensajes
4. **Validacion con `stopifnot()`**: precondiciones verificadas al inicio de cada funcion.
5. **Documentacion roxygen**: `#' @param`, `#' @return`, `#' @description`, `#' @export`.

### Ejemplo de firma

```r
convert_structural_zeros_to_na <- function(data, zero_vars = NULL, verbose = FALSE)
# Retorna: tibble con attr("zero_summary")
```

### Pipeline maestro

`transform_generic_ames()` encadena las funciones individuales en orden logico con parametros configurables, implementando el patron Pipeline/Chain of Responsibility.

## Justificacion

- **Funciones puras** vs mutacion in-place: R es un lenguaje con semantica copy-on-modify; el patron es idiomatico y previene bugs por efectos colaterales.
- **Atributos** vs columnas de log: los atributos no contaminan el data.frame con columnas extra; son metadata out-of-band que viajan con el objeto pero no interfieren con operaciones de datos.
- **verbose** vs logging global: el parametro verbose permite que el mismo codigo sirva para uso interactivo (verbose = TRUE) y para ejecucion en batch/render (verbose = FALSE).

## Consecuencias

- **Positivas**: pipeline completamente auditable; funciones testables de forma aislada; los capitulos .qmd pueden mostrar resumenes con `attr(obj, "zero_summary") %>% kable()`.
- **Negativas**: los atributos R se pierden con ciertas operaciones de tidyverse (ej. `bind_rows`, algunos `mutate`). El patron `verbose` duplica la logica de retorno.
- **Mitigacion**: las funciones del pipeline maestro se ejecutan secuencialmente preservando atributos; los resumenes se extraen inmediatamente despues de cada paso.
