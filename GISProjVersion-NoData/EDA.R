library(ggplot2)
library(sf)
library(tidyverse)

mapTheme <- theme_minimal() + theme(
  axis.line = element_blank(),
  axis.text = element_blank(),
  legend.position = "none", #no legend, we die like men
  panel.grid = element_blank()
)

theme_set(mapTheme)

pathCA <- "2020ResultsByPrecinct/ca_2020/ca_2020.shp"

dataCA <- st_read(pathCA)
head(dataCA)
class(dataCA)

alameda <- dataCA %>%
  filter(COUNTY == "Alameda")

ccc <- dataCA %>%
  filter(COUNTY == "Contra Costa")

print(dataCA)

sum(is.na(dataCA$geometry))

basicMap <- ggplot(
  data = dataCA
) +
  geom_sf() +
  theme_minimal()

(basicMap)

alamedaMap <- ggplot(alameda) + geom_sf()

(alamedaMap)

cccMap14 <- ggplot(
  data = (ccc %>% filter(ADDIST == 14))
  ) + 
  geom_sf()

(cccMap14)

(unique(ccc$CDDIST))

sum(is.na(deSaulnier$DemVoteShare))

problemKids <- deSaulnier %>%
  filter(is.na(DemVoteShare))

colnames(deSaulnier)

deSaulnier <- dataCA %>%
  filter(COUNTY == "Contra Costa") %>%
  mutate(NumCanvassers = 0) %>%
  select(-COUNTY, -CNTY_CODE, -FIPS_CODE, -SRPREC_KEY, -ADDIST, -SDDIST, -BEDIST) %>%
  rename("Precinct" = "SRPREC",
         "Dem" = "G20PREDBID",
         "Rep" = "G20PRERTRU",
         "Liber" = "G20PRELJOR",
         "Green" = "G20PREGHAW",
         "AmerIndep" = "G20PREAFUE",
         "PeaceFreedom" = "G20PREPLAR"
  ) %>%
  mutate(DemVoteShare = (Dem / (Dem + Rep + Liber + Green + AmerIndep + PeaceFreedom))) %>%
  mutate(PrecinctVotes = (Dem+Rep+Liber+Green+AmerIndep+PeaceFreedom)) %>%
  mutate(PercVotersInPrecinct = PrecinctVotes / sum(ccc$PrecinctVotes)) %>%
  mutate(DidNotVoteDemNPP = round((PercVotersInPrecinct * 703021 * (1-0.8409)), 0)) %>%
  filter(CDDIST == 11) %>%
  select(-CDDIST)

sum(deSaulnier$PrecinctVotes)
  

deSaulMap <- ggplot(
  data = deSaulnier,
  aes(fill = (G20PREDBID / (G20PREDBID + G20PRERTRU + G20PRELJOR + G20PREGHAW + G20PREAFUE + G20PREPLAR)))
) +
  geom_sf()

(deSaulMap)
packageVersion("leaflet")

sum(ccc$PrecinctVotes)

print(deSaulnier[13][1])


