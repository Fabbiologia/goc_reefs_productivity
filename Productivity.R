# load 

library(dplyr)
library(tidyverse)
library(ramify)
library(ggplot2)
library(openxlsx)

# load data -----------------

tabla <- read.xlsx("data/tabl_parametrs.xlsx") |> 
  filter(
         Family %in% c ("Serranidae", "Lutjanidae", "Carangidae", "Scaridae", "Scombridae"),
  ) |> 
  mutate(sstmean = 25.5) |> 
  mutate(Diet = factor(Diet,  
                       levels = c("HerMac", "HerDet", "Omnivr", "Plktiv", "InvSes", "InvMob", "FisCep")),
         Position = factor(Position,  
                           levels = c("PelgAs", "PelgDw", "BtPlAs", "BtPlDw", "BnthAs", "BnthDw")),
         Method = factor(Method,
                         levels = c("LenFrq", "MarkRc", "Otolth", "Unknown", "OthRin", "ScalRi")))


fish <- readRDS("data/LTEM_historic_updated_27122022.RDS") |> 
  mutate(Family = ifelse(Genus == "Rypticus", "Grammistidae", Family)) |> 
  filter(Label == "PEC",
         Family %in% c ("Serranidae", "Lutjanidae", "Carangidae", "Scaridae", "Scombridae"),
  ) |> 
  mutate(
    A_ord = as.numeric(A_ord),
    B_pen= as.numeric(B_pen),
    Quantity = as.numeric(Quantity),
    Size=as.numeric(Size),
    Area= as.numeric(Area),
    Month= as.numeric(Month),
    Biomass = (Quantity * A_ord* (Size^B_pen))/(Area * 100)) |>  
  mutate(
    Biomass=as.numeric(Biomass),
    TrophicGroup = factor(TrophicGroup, 
                          levels = c("Piscivoro", 
                                     "Carnivoro", 
                                     "Herbivoro", 
                                     "Zooplanctivoro")), 
    Region = factor(Region),
    TrophicLevelF = cut(as.numeric(TrophicLevel), 
                        breaks = c(2, 2.5, 3, 3.5, 4, 4.6), 
                        labels = c("2-2.5", "2.5-3", "3-3.5", "3.5-4", "4-4.5"), 
                        right = FALSE)) |> 
  mutate(Species = recode(Species, "Rypticus courtenayi   " = "Rypticus courtenayi",
                          "Carangoides orthogrammus" = "Ferdauia orthogrammus",
                          "Epinephelus acanthistius" = "Hyporthodus acanthistius")) 
# 
# fish_ltem <- left_join(fish_ltem, tabl, by = c( "Family", "Species", "A_ord", "B_pen"))
# 
merged_data <- merge(fish, tabla, by = c("Family", "Species", "A_ord", "B_pen"), all.x = TRUE)


# fish_ltem <- read.xlsx("data/fish_parametros.xlsx") |> # merged_data 
fish_islotes <- merged_data |> 
  filter(Region == "La Paz", Reef == "ESPIRITU_SANTO_ISLOTES_ESTE") |> 
  mutate(Diet = factor(Diet,  
                       levels = c("HerMac", "HerDet", "Omnivr", "Plktiv", "InvSes", "InvMob", "FisCep")),
         Position = factor(Position,  
                           levels = c("PelgAs", "PelgDw", "BtPlAs", "BtPlDw", "BnthAs", "BnthDw")),
         Method = factor(Method,
                         levels = c("LenFrq", "MarkRc", "Otolth", "Unknown", "OthRin", "ScalRi")))

# # SpecCode, Diet, Position, Method
# fish_ltem <- merge(fish_ltem, db[, c('Species', 'SpecCode', 'Diet', 'Position', 'Method')],
#                    by = 'Species', all.x = TRUE, suffixes = c("", ".db"))
# 
# # Si hay columnas duplicadas después de la combinación, eliminar las duplicadas de .db
# duplicated_columns <- names(fish_ltem)[duplicated(names(fish_ltem))]
# fish_ltem <- fish_ltem[, !grepl("\\.db$", names(fish_ltem)) | !names(fish_ltem) %in% duplicated_columns]
# 
# # Si hay columnas duplicadas después de la combinación, renombrar las columnas en .db
# for (col in setdiff(names(fish_ltem), names(db))) {
#   if (grepl("\\.db$", col)) {
#     new_colname <- gsub("\\.db$", "", col)
#     names(fish_ltem)[names(fish_ltem) == col] <- new_colname
#   }
# }
# 
# # Tallas maximas
# fish_ltem <- fish_ltem |> 
#   group_by(Species) |> 
#   mutate(MaxSizeTL = max(Size)) |> 
#   ungroup()
# 
# Lmeas <- fish_ltem$Size # Vector de tallas iniciales
# a <- fish_ltem$A_ord
# b <- fish_ltem$B_pen

t <- 365

tabla <- tabla |> 
  mutate( Kmax = K / LinfTL)


# Calcular la masa corporal individual -----------

fish_ltem <- fish_islotes |> 
  # rename(a = A_ord, b = B_pen, lon = Longitude, lat = Latitude, Lmeas = Size) |> 
  mutate(Mti = A_ord * (Size ^ B_pen))
# mutate(Mti = a * (Lmeas ^ b))
  # mutate(Biomass = (Quantity * A_ord* (Size^B_pen))/(Area * 100))

# Biomasa total del conjunto de peces (Biomasa en pie):

biomasa_total <- fish_islotes |> 
  
  summarise(B_t = sum(Biomass))

head(db)
str(fish_ltem)
unique(db$Diet)

# sstmean 
fish_ltem <- fish_islotes |> 
  mutate(sstmean = 25.5) 
# |>
#   select(Family, Species, SpecCode, Size, Biomass, MaxSizeTL, Diet,
#          Position, A_ord, B_pen, LinfTL, K, O, Longitude, Latitude, sstmean, Method)

fish_ltem$SpecCode <-as.integer(fish_ltem$SpecCode)


# Predicts standardised growth parameter Kmax for reef fishes ----------------
# predKmax(traits, dataset, fmod, params = NULL, niter, nrounds = 150, verbose = 0, print_every = 1000, return = c('pred', 'relimp', 'models'), lowq = 0.25, uppq = 0.75) 

Kmaxpred <- predKmax(traits = fish_ltem, dataset = tabla, fmod = ~ sstmean + MaxSizeTL + Diet + Position + Method, niter = 1000)

# Acceder al elemento 'pred' de la lista Kmax
Kmax_pred <- Kmaxpred$pred

a0_estimates <- predM(Lmeas = fish_ltem$Size, Lmax = fish_ltem$MaxSizeTL, Kmax = Kmax_pred$Kmax, temp = fish_ltem$sstmean, method = 'Pauly')

# Kmax_pred <- Kmax_pred |> 
#   select(Family, Species, SpecCode, Size, MaxSizeTL, Diet, Position, A_ord, B_pen, Longitude, Latitude, sstmean, Kmax)


# Applying_growth 
# Applies VBGF to fish length data ---------------------
# applyVBGF (Lmeas, t = 1, Lmax, Kmax, L0, t0, t0lowbound = -0.5,  silent = T)

resultado_longitud <- applyVBGF(Lmeas = fish_ltem$Size, t = t, Lmax = fish_ltem$MaxSizeTL, Kmax = Kmax_pred$Kmax, t0 = a0_estimates)

Lgr <- resultado_longitud # Vector de tallas calculadas con VBGF
ctrgr(Lmeas = fish_ltem$Size, Lgr, silent = FALSE) # Verificar si el crecimiento es válido

# Expected somatic growth in weight----------------
# somaGain (a, b, Lmeas, t = 1, Lmax, Kmax, t0, t0lowbound = -0.5,  silent = T)

resultado_pesos <- somaGain(a = fish_ltem$A_ord, b = fish_ltem$B_pen, Lmeas = fish_ltem$Size, t = t, Lmax = fish_ltem$MaxSizeTL, Kmax = Kmax_pred$Kmax, t0 = a0_estimates)

#   Predicts natural mortality rates Z/M for reef fishes -----------
# predM (Lmeas, t = 1, Lmax, Kmax, temp, Lr, p = 0.5, exp = -0.91, method = c('Lorenzen'))

predicciones_mortalidad <- predM(Lmeas = fish_ltem$Size, t = t, Lmax = fish_ltem$MaxSizeTL, Kmax = fish_ltem$MaxSizeTL, temp = fish_ltem$sstmean, Lr, p = 0.5, exp = -0.91, method = 'Lorenzen')

M <- predicciones_mortalidad 

# Applying_mortality
# Expected per capita loss due to natural mortality ---------------
# somaLoss (M, Wei, Lmeas, a, b, t = 1)

perdida_per_capita <- somaLoss(M = M, Lmeas = fish_ltem$Size, a = fish_ltem$A_ord, b = fish_ltem$B_pen, t = t)

# Applies stochastic natural mortality -----------
# applyMstoch(M, t = 1) 

stochastic <- applyMstoch(M, t = t)
# applyMstoch(M, t) # Generar muestras aleatorias de sobrevivencia


# Productividad = Biomasa + Crecimiento Somático Total - Pérdidas debido a la Mortalidad ------

# standing_biomass <- sum(Biomass)

# Calcular el Crecimiento Somático Total (suma de ganancias de peso)
crecimiento_somatico_total <- sum(resultado_pesos)

# Calcular las Pérdidas debido a la Mortalidad (suma de pérdidas de peso por mortalidad)
perdidas_mortalidad <- sum(perdida_per_capita)


# Productividad -------
productividad <- (biomasa_total + crecimiento_somatico_total - perdidas_mortalidad)


print(productividad)


fish_ltem$Kmax_pred <- Kmax_pred$Kmax
fish_ltem$a0 <- a0_estimates
fish_ltem$length <- resultado_longitud
fish_ltem$weight <- resultado_pesos
fish_ltem$M <- M
fish_ltem$Perdida <- perdida_per_capita
fish_ltem$Stochastic <- stochastic

produc_islotes<- fish_ltem |> 
  mutate(Productivity = Biomass + weight - Perdida)



# Crear un dataframe con las tallas observadas y calculadas
data_plot <- data.frame(
  Lmeas = fish_ltem$Size,
  Lgr = Lgr
)


# Graficar las tallas observadas y calculadas
ggplot(data_plot, aes(x = Lmeas, y = Lgr)) +
  geom_point(color = "blue") +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
  labs(x = "Talla Observada (Lmeas)", y = "Talla Calculada (Lgr)") +
  theme_minimal()


# Crear un dataframe con los tamaños máximos y la temperatura del agua
data_maxsize_temp <- data.frame(
  TamanoMaximo = fish_ltem$MaxSizeTL,
  TemperaturaAgua = fish_ltem$sstmean
)

# Gráfica de dispersión del tamaño máximo vs. temperatura del agua
ggplot(data_maxsize_temp, aes(x = TemperaturaAgua, y = TamanoMaximo)) +
  geom_point(color = "purple") +
  labs(x = "Temperatura del Agua", y = "Tamaño Máximo") +
  theme_minimal()

