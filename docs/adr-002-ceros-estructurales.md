# ADR-002: Tratamiento de ceros estructurales en variables numericas

**Estado**: Aceptada
**Fecha**: 2025-06-28
**Capitulo relacionado**: 03-data-cleaning

## Contexto

Varias variables numericas del dataset usan `0` para codificar la ausencia de un componente estructural (ej. `Garage_Area = 0` cuando no hay garaje, `Pool_Area = 0` cuando no hay piscina). Estos ceros no representan mediciones reales de magnitud nula, sino ausencia del componente.

Mantener estos ceros sin tratamiento:
- Distorsiona estadisticos descriptivos (media, varianza, asimetria).
- Introduce bimodalidad artificial en las distribuciones.
- Impide transformaciones logaritmicas directas.
- Confunde modelos predictivos al mezclar "no tiene" con "tiene pero mide cero".

## Decision

Convertir ceros estructurales a `NA` para las 13 variables identificadas, y complementar con indicadores binarios `has_*` donde corresponda.

### Variables cuyos ceros se convierten a NA

| Variable | Criterio principal |
|---|---|
| Pool_Area | 99.56% ceros, ausencia de piscina |
| Three_season_porch | 98.74% ceros |
| Misc_Val | 96.48% ceros, discrepancias con Misc_Feature |
| Bsmt_Half_Bath | 94.03% ceros |
| Screen_Porch | 91.26% ceros |
| BsmtFin_SF_2 | 88.02% ceros |
| Enclosed_Porch | 84.33% ceros |
| Mas_Vnr_Area | 60.44% ceros, discrepancias con Mas_Vnr_Type |
| Bsmt_Full_Bath | 58.33% ceros |
| Wood_Deck_SF | 52.08% ceros |
| Lot_Frontage | 16.72% ceros (falta de medicion) |
| Garage_Area | 5.39% ceros, discrepancias con Garage_Type |
| Garage_Cars | 5.39% ceros |

### Variables cuyos ceros se conservan

Variables como `Second_Flr_SF`, `Fireplaces`, `Open_Porch_SF`, `Half_Bath`, `Full_Bath`, `Bedroom_AbvGr`, `Kitchen_AbvGr`, `BsmtFin_SF_1`, `Bsmt_Unf_SF` conservan sus ceros porque representan valores legitimos dentro de la escala de medicion.

## Justificacion

- Criterios de decision: proporcion de ceros > 50%, discrepancias confirmadas con variables categoricas pareadas, o significado semantico del cero como ausencia (no como magnitud).
- Se usa la funcion `convert_structural_zeros_to_na()` que registra cuantos ceros se convirtieron por variable en el atributo `"zero_summary"`.

## Consecuencias

- **Positivas**: estadisticos descriptivos reflejan solo mediciones reales; transformaciones log/sqrt aplicables sin ajustes ad-hoc; modelos pueden distinguir "no tiene" (NA) de "tiene pero es bajo".
- **Negativas**: se introducen NAs que requieren tratamiento en modelado (imputacion o exclusion). Aumenta la complejidad del pipeline.
- **Mitigacion**: indicadores binarios `has_*` preservan la informacion de presencia/ausencia sin perdida.
