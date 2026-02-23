# ADR-003: Tratamiento de ausencias estructurales en variables categoricas

**Estado**: Aceptada
**Fecha**: 2025-06-28
**Capitulo relacionado**: 03-data-cleaning

## Contexto

El dataset codifica la ausencia de componentes estructurales mediante niveles categoricos especiales: `"None"`, `"No_Garage"`, `"No_Basement"`, `"No_Pool"`, `"No_Fence"`, `"No_Alley_Access"`. Estos niveles son formalmente validos como niveles de un factor en R, pero no representan categorias sustantivas del fenomeno.

Sin tratamiento, los modelos estadisticos (regresion con dummies, arboles de decision) tratan estos niveles como clases legitimas, lo que puede introducir sesgos e interpretaciones erroneas.

## Decision

1. Identificar sistematicamente los niveles de ausencia (`none_levels`).
2. Crear indicadores binarios `has_<variable>` (0/1) para cada variable categorica con niveles de ausencia.
3. Recodificar pares categorico-numericos discordantes (ver ADR-004).

### Niveles de ausencia definidos

```r
none_levels <- c("None", "No_Alley_Access", "No_Pool",
                 "No_Fence", "No_Garage", "No_Basement")
```

### Indicadores creados

- Desde categoricas: `has_pool_qc`, `has_mas_vnr_type`, `has_garage_cond`, `has_bsmt_cond`, `has_fence`, `has_alley`
- Desde numericas: `has_second_flr_sf`, `has_fireplaces`

## Justificacion

- Los indicadores binarios permiten a los modelos distinguir presencia/ausencia sin perder la granularidad de las categorias sustantivas.
- Se implementa con las funciones `create_has_indicators()` y `create_has_num_indicators()` que registran conteos en atributos R.
- El patron es consistente con la recomendacion de De Cock de crear variables indicadoras (dummies) para facilitar la integracion de efectos cualitativos.

## Consecuencias

- **Positivas**: separacion limpia entre presencia y tipo/calidad; modelos pueden usar has_* como intercepto y las categorias sustantivas como pendientes condicionales.
- **Negativas**: aumento en el numero de columnas del dataset. Potencial redundancia si se usan has_* junto con la variable categorica original.
- **Mitigacion**: seleccion de features en etapa de modelado eliminara redundancias.
