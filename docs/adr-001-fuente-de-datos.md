# ADR-001: Fuente de datos — modeldata::ames

**Estado**: Aceptada
**Fecha**: 2025-06-28
**Capitulo relacionado**: 02-data-description

## Contexto

El dataset Ames Housing original (De Cock, 2011) contiene 2930 observaciones y ~80 variables. Existen multiples versiones disponibles: el CSV crudo del articulo, versiones de Kaggle, y la version curada del paquete R `{modeldata}` (Kuhn, 2024).

Se necesitaba elegir una fuente que equilibrara fidelidad al original con calidad de preprocesamiento inicial.

## Decision

Usar `modeldata::ames` como fuente unica de datos.

## Justificacion

- Conserva las 2930 observaciones del articulo original.
- Reduce de ~80 a 74 variables, eliminando 8 que son proxies encubiertos del precio (`Overall_Qual`, `Exter_Qual`, `Bsmt_Qual`, `Kitchen_Qual`, `Fireplace_Qu`, `Garage_Qual`, `Garage_Yr_Blt`, `Low_Qual_Fin_SF`) mas `Order` y `PID`. Esto previene endogeneidad.
- Agrega `Longitude` y `Latitude` para analisis espacial.
- Adopta etiquetas legibles para abreviaciones cripticas en factores (ej. `"Typ"` → `"Typical"`).
- Conserva exclusivamente ventas residenciales unicas (sin duplicados).
- Es reproducible con `data(ames)` sin necesidad de gestionar archivos CSV externos.

## Consecuencias

- **Positivas**: menor preprocesamiento inicial, reproducibilidad trivial, sin archivos grandes en el repositorio.
- **Negativas**: se pierden 8 variables que podrian ser utiles en ciertos analisis; no se tiene control sobre decisiones de curado del paquete. Las variables excluidas por `{modeldata}` no estan disponibles para modelado.
- **Mitigacion**: se documenta la lista completa de exclusiones en el cap. 2 para transparencia.
