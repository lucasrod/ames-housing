## ---- setup-global ----
message("[setup.R] cargando configuraciones globales")

## ---- setup-libraries ----
library(tidyverse)
library(scales)
library(knitr)
library(conflicted)
conflict_prefer("filter", "dplyr")

## ---- setup-options ----
theme_set(theme_minimal())
options(dplyr.summarise.inform = FALSE)