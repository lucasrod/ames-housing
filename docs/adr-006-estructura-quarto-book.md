# ADR-006: Estructura del Quarto Book y gestion de tablas

**Estado**: Aceptada
**Fecha**: 2025-06-28
**Archivo relacionado**: _quarto.yml

## Contexto

El proyecto necesitaba un formato de reporte que soportara:
- Narrativa extensa con multiples capitulos.
- Codigo R ejecutable embebido.
- Cross-references entre capitulos, tablas y figuras.
- Apendices para material complementario.
- Citas bibliograficas con estilo academico.
- Output HTML navegable con tabla de contenidos.

## Decision

Usar **Quarto Book** (project type: book) con output HTML.

### Estructura de capitulos

- 8 capitulos numerados (`01-introduction.qmd` a `08-conclusions.qmd`) siguiendo kebab-case.
- 2 apendices: diccionario de variables (`09-data-dictionary.qmd`) y tablas complementarias (`10-tbl-appendix.qmd`).
- Prefacio en `index.qmd`, referencias en `chapters/references.qmd`.

### Estrategia de gestion de tablas

Las tablas pesadas o reutilizadas se centralizan en `chapters/10-tbl-appendix.qmd` y se incrustan en otros capitulos mediante la directiva Quarto:

```markdown
{{< embed 10-tbl-appendix.qmd#tbl-label echo=TRUE >}}
```

Esto evita duplicar codigo de generacion de tablas y garantiza consistencia.

### Scripts como fuente de funciones

- Los scripts R (`scripts/*.R`) definen funciones pero no ejecutan logica.
- Los capitulos cargan las funciones via `knitr::read_chunk()` o `source()`.
- `.Rprofile` carga `setup.R` y `funciones-tablas.R` automaticamente al inicio de sesion.

### Configuracion de cross-references

Prefijos en espanol configurados en `_quarto.yml`:
- `fig-title: "Figura"`, `fig-prefix: "figura"`
- `tbl-title: "Tabla"`, `tbl-prefix: "tabla"`

### Citas

- BibTeX en `references.bib`
- Estilo Chicago fullnote-with-ibid (`csl/chicago-fullnote-with-ibid.csl`)
- Ubicacion: margen (`citation-location: margin`)

## Justificacion

- Quarto Book es el formato nativo de Quarto para documentos multi-capitulo con R; soporta cross-refs, citas y apendices out-of-the-box.
- La centralizacion de tablas en el apendice con `embed` reduce duplicacion y facilita el mantenimiento (single source of truth para cada tabla).
- HTML con tema `cosmo` + `code-fold: true` permite navegacion interactiva y exploracion del codigo.

## Consecuencias

- **Positivas**: informe navegable, reproducible, con cross-refs automaticos y codigo visible/ocultable.
- **Negativas**: la directiva `embed` requiere que el capitulo embebido se renderice primero; si falla, los capitulos que lo usan tambien fallan. El render completo puede ser lento.
- **Mitigacion**: el apendice de tablas es autocontenido y tiene pocas dependencias, minimizando fallos en cascada.
