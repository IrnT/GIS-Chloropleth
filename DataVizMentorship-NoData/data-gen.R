library(sf)
library(dplyr)

# Read GeoJSON file (e.g., from disk or URL)
dataCA_json <-sf::st_read("ccc.json")

#How many voters each canvasser reaches
avgResourceReach <- 62.5 

#The percent of reached voters convinced to vote
chanceTurnout <- 0.09

#Total registered voters in county
registeredVoters <- 703021

#Election Turnout
countyWideTurnout <- 0.8409
ccc <- 581230 #num votes cast in contra costa

#Combined percentage county wide of both Dem and NPP voters
countyWideDemNPPPercent <- 0.7501

# Apply the same transformations
deSaulnier <- dataCA_json %>%
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
  mutate(PrecinctVotes = (Dem + Rep + Liber + Green + AmerIndep + PeaceFreedom)) %>%
  mutate(PercVotersInPrecinct = PrecinctVotes / ccc) %>%
  mutate(
    DidNotVoteDemNPP = 
      round((PercVotersInPrecinct * registeredVoters * (1 - countyWideTurnout) * countyWideDemNPPPercent), 0)
  ) %>%
  filter(CDDIST == 11) %>%
  select(-CDDIST)

s# Optional: Write modified data back to GeoJSON
st_write(deSaulnier, "path/to/output.geojson", driver = "GeoJSON")
