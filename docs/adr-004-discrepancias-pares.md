# ADR-004: Resolucion de discrepancias en pares categorico-numericos

**Estado**: Aceptada
**Fecha**: 2025-07-03
**Capitulo relacionado**: 03-data-cleaning

## Contexto

En el dataset existen pares de variables donde una categorica describe la presencia/calidad de un componente y una numerica mide su magnitud. Se detectaron dos tipos de inconsistencias internas:

1. **Presente pero cero**: la categorica indica presencia (ej. `Garage_Type = "Attchd"`) pero la numerica es 0 (ej. `Garage_Area = 0`).
2. **Ausente pero positivo**: la categorica indica ausencia (ej. `Garage_Type = "No_Garage"`) pero la numerica es > 0 (ej. `Garage_Area = 200`).

### Pares analizados

| Categorica | Numerica |
|---|---|
| Garage_Type | Garage_Area |
| Garage_Cond | Garage_Area |
| Bsmt_Cond | Total_Bsmt_SF |
| Bsmt_Exposure | Total_Bsmt_SF |
| Pool_QC | Pool_Area |
| Mas_Vnr_Type | Mas_Vnr_Area |
| Misc_Feature | Misc_Val |

## Decision

Reglas de resolucion asimetricas segun el tipo de discrepancia:

### Presente pero cero (cat != None, num == 0)
- **Conservar** la etiqueta categorica (se asume que la informacion cualitativa es correcta).
- **Convertir** el valor numerico 0 → NA (se interpreta como dato faltante de medicion).
- Razonamiento: es mas probable que falte una medicion numerica a que se haya registrado un tipo de garaje inexistente.

### Ausente pero positivo (cat ∈ none_levels, num > 0)
- **Recodificar** la variable categorica al nivel mas frecuente (moda) excluyendo niveles de ausencia.
- **Conservar** el valor numerico positivo (se asume que la medicion es correcta).
- Razonamiento: si hay una medicion positiva, el componente existe; la etiqueta de ausencia es el error.

## Justificacion

- Las reglas priorizan el dato mas informativo: la medicion positiva sobre la etiqueta de ausencia, y la etiqueta sustantiva sobre el cero numerico.
- Se implementa con `recode_categorical_absence()` que registra cuantas recodificaciones se hicieron por variable y a que nivel, en el atributo `"recode_summary"`.
- La moda como valor de imputacion categorica es una estrategia conservadora que minimiza la distorsion de la distribucion.

## Consecuencias

- **Positivas**: coherencia interna garantizada entre pares; pipeline downstream puede asumir consistencia cat-num.
- **Negativas**: la imputacion por moda pierde informacion sobre la categoria real del componente en los casos discordantes. El numero de casos afectados es bajo (tipicamente < 5 por par).
- **Mitigacion**: el resumen de recodificaciones queda registrado como atributo para auditoria.
