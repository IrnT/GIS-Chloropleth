#libraries!
library(sf)
library(tidyverse)

#Total registered voters in county
registeredVoters <- 703021

#Election Turnout
countyWideTurnout <- 0.8409

#Number of votes cast county-wide
ccc <- 581230

#Combined percentage county wide of both Dem and NPP voters
countyWideDemNPPPercent <- 0.7501

#reading in shapefile and transforming to appropriate crs
pathCA <- "TurnoutDifferenceCalculator/data/ca_2020/ca_2020.shp"
dataCA <- quietly(st_read)(pathCA)
dataCA <- st_transform(dataCA, crs = 4326)

#mutating + filtering for plotting
deSaulnier <- dataCA %>%
  
  #grab only the data from Contra Costa County, which entirely contains US House District 11
  filter(COUNTY == "Contra Costa") %>%
  
  #adds a column to hold the number of canvassers
  mutate(NumCanvassers = 0) %>%
  
  #drops unnecessary columns
  select(-COUNTY, -CNTY_CODE, -FIPS_CODE, -SRPREC_KEY, -ADDIST, -SDDIST, -BEDIST) %>%
  
  #renames for slightly more human readability
  rename("Precinct" = "SRPREC",
         "Dem" = "G20PREDBID",
         "Rep" = "G20PRERTRU",
         "Liber" = "G20PRELJOR",
         "Green" = "G20PREGHAW",
         "AmerIndep" = "G20PREAFUE",
         "PeaceFreedom" = "G20PREPLAR"
  ) %>%
  
  #creates the percentage of votes in each precinct that were Democratic
  mutate(DemVoteShare = (Dem / (Dem + Rep + Liber + Green + AmerIndep + PeaceFreedom))) %>%
  
  #creates a total votes cast in precinct column
  mutate(PrecinctVotes = (Dem+Rep+Liber+Green+AmerIndep+PeaceFreedom)) %>%
  
  #calculates what percentage this precinct made up of all votes cast in the county
  mutate(PercVotersInPrecinct = PrecinctVotes / ccc) %>%
  
  #this is one of the funky transformations!
  #this is the number of untapped Dems (or dem-willing NPPs) that are estimated to exist in the precinct
  #the formula is to multiply the total county wide registered voters by the percentage of voters this district DID have
  #to estimate the total number of voters in the precinct
  #that number is then multiplied by the inverse of the county wide turnout percentage
  #to estimate the number of voters who did not vote but could have, regardless of party
  #that is then multiplied by likelihood that any randomly selected voter will be a Democrat or a NPP (75.01%)
  #which results in the number of people who could be convinced to vote for a Democrat but did not
  mutate(
    DidNotVoteDemNPP = 
      round((PercVotersInPrecinct * registeredVoters * (1 - countyWideTurnout) * countyWideDemNPPPercent), 0)
  ) %>%
  
  #this step isolates only US House District 11, deSaulnier's district
  filter(CDDIST == 11) %>%
  
  #and then removes the house column as it is no longer needed
  select(-CDDIST)

head(deSaulnier)
