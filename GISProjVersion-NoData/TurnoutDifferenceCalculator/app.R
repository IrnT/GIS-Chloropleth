## LIBRARIES

library(shiny)
library(sf)
library(leaflet)
library(tidyverse)
library(rsconnect)

## GLOBAL VARIABLES

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

### INITIAL DATA PREP ###

#reading in shapefile and transforming to appropriate crs
pathCA <- "data/ca_2020/ca_2020.shp"
dataCA <- st_read(pathCA)
dataCA <- st_transform(dataCA, crs = 4326)

#mutating + filtering for plotting
#this logic is broken down in an earlier section of the writeup!
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
  mutate(PercVotersInPrecinct = PrecinctVotes / ccc) %>%
  mutate(
    DidNotVoteDemNPP = 
      round((PercVotersInPrecinct * registeredVoters * (1 - countyWideTurnout) * countyWideDemNPPPercent), 0)
  ) %>%
  filter(CDDIST == 11) %>%
  select(-CDDIST)

## COLOR PALETTE ##

#Color palette selection (defined here so it knows deSaulnier exists!)
palette <- colorNumeric(
  palette = c("black", "yellow"),
  domain = c(deSaulnier$DidNotVoteDemNPP),
  na.color = "white"
)

## UI DEFINITION SECTION ##

ui <- fluidPage(
  
  #title header
  titlePanel("Campaign Resource Allocation Assistant"),
  
  sidebarLayout(
    
    ### SIDEBAR LAYOUT ###
    sidebarPanel(
      
      #initial instructions
      helpText("Use this tool to simulate voter turnout in precincts across this Congressional district, to be sure that we are effectively reaching untapped Democratic voters.\n\n
               You can select a precinct from the dropdown list below, or click a precinct on the map on the left."),
      
      #precinct dropdown menu
      selectInput("precinctSelection", "Select Precinct:",
                  choices = deSaulnier$Precinct),
      
      #slider instructions
      helpText("Here you use the slider to select how many canvassers you'd like to simulate sending to this precinct."),
      
      #slider for selecting number of canvassers to send to precinct
      sliderInput("canvassers", "Canvassers To Send to Precinct",
                  min = 0, max = 100, value = 5),
      
      #press that button kid!
      helpText("Once you've selected your precinct and used the slider to allocate canvassers, you can press the button below to view the effect this would have on the election!"),
      
      #makes the thing to the thing
      actionButton("update", "Send Canvassers!"),
      
      #contextualizes reset to historical
      helpText("Or, if you'd like to simulate a different tactic, you can click the button below to reset the map to the starting state."),
      
      #resets to base DeSaulnier
      actionButton("reset", "Reset to Historical"),
      
      #adds a horizontal bar since it looks nice
      hr(),
      
      #Reportout on how the election currently stands.
      h4("Current Election Results"),
      verbatimTextOutput("summaryBox")
      
    ),
    
    ### MAIN PANEL LAYOUT ###
    mainPanel(
      leafletOutput("map", height = "600px"),
      verbatimTextOutput("warningText")
    )
  )
)


## SERVER DEFINITION SECTION ##

server <- function(input, output, session) {
  
  #Initialize map data set as cleaned deSaulnier, and make it reactive to input
  outputData <- reactiveVal(deSaulnier)
  
  #Sets messages to empty for next round of actions
  warnings <- reactiveVal("")
  
  ### MAP GENERATION SECTION ###
  
  #sets what is displayed in main panel via leaflet
  output$map <- renderLeaflet({
    
    #sends whatever is the current outputData to the map
    leaflet(outputData()) %>%
      
      #this does the background! thank you stadia
      addTiles() %>%
      addProviderTiles("Stadia.StamenTonerLite") %>%
      
      #this maps the precinct polygons based on the geometry column
      addPolygons(
        
        #below line is just aesthetics
        color = "black", weight = 1, opacity = 1, fillOpacity = 0.75, 
        
        #sets the fill color to the number of unactivated dems/NPPs in the district
        fillColor = ~palette(DidNotVoteDemNPP),
        
        #hover label
        label = ~paste0("Precinct: ", Precinct, " - ",
                        "Untapped Dem Voters: ", DidNotVoteDemNPP, " - ",
                        "Canvasser Sent: ", NumCanvassers),
        
        #hopefully the layerID for clicking!
        layerId = ~Precinct
      ) %>%
      
      #adds a legend
      addLegend(
        "topright", pal = palette, opacity = 1,
        values = ~(DidNotVoteDemNPP), title = "Untapped Dems"
      )
    
  })
  
  #sets the map to an observe (meaning, updates on changes to outputData())
  observe({
    
    #clears out old map and tells this one where to go
    #very similar to above
    leafletProxy("map") %>%
      clearShapes() %>%
      addPolygons(
        data = outputData(),
        color = "black", weight = 1, opacity = 1, 
        fillOpacity = 0.75, fillColor = ~palette(DidNotVoteDemNPP),
        label = ~paste0("Precinct: ", Precinct, " - ",
                        "Untapped Dem Voters: ", DidNotVoteDemNPP, " - ",
                        "Canvasser Sent: ", NumCanvassers),
        layerId = ~Precinct
      )
  })

  ### MINOR TWEAK - WHAT HAPPENS WHEN THEY CLICK ON THE MAP ###
  #this will hopefully alter it so the dropdown menu will auto populate to the clicked district
  observeEvent(input$map_shape_click, {
    clicked_precinct <- input$map_shape_click$id
    updateSelectInput(session, "precinctSelection", selected = clicked_precinct)
  })
  
  ### WHAT HAPPENS WHEN THEY PRESS SEND ###
  observeEvent(input$update, {
    
    #requires that there be a precinct selection to run
    req(input$precinctSelection)
    
    #slices just the selected precinct for validations
    currPrec <- outputData() %>% filter (Precinct == input$precinctSelection)
    
    #saves the number of activated dems that would result
    activatedDems <- round((input$canvassers * avgResourceReach * chanceTurnout),0)
    
    #resets warnings, in case that didn't already happen
    warnings("")
    
    #checks to make sure that we wouldn't go above the number of unactivated Dems
    #if that is the case, exit this prematurely without updating the map
    #warn the user if so
    if(activatedDems > currPrec$DidNotVoteDemNPP){
      warnings("Not enough Dems to activate for canvasser time to be useful!\nTry sending fewer canvassers, or select a different precinct.")
      return()
    }
    
    #changes to dataframe behind map!
    updated <- outputData() %>%
      
      #update with number of canvassers sent
      mutate(NumCanvassers = ifelse(
        Precinct == input$precinctSelection,
        input$canvassers,
        NumCanvassers)
      ) %>%
      
      #update Dem count based on number activated above
      mutate(
        Dem = ifelse(
          Precinct == input$precinctSelection,
          Dem + activatedDems, #equation for recalc goes here!,
          Dem)
      ) %>%
      
      #reduce unactivated voter count
      mutate(DidNotVoteDemNPP = ifelse(
        Precinct == input$precinctSelection,
        DidNotVoteDemNPP - activatedDems,
        DidNotVoteDemNPP)
      ) %>%
      
      #add activated votes to precinct tallies
      mutate(PrecinctVotes = ifelse(
        Precinct == input$precinctSelection,
        PrecinctVotes + activatedDems,
        PrecinctVotes
        )
      )
    
    #sends update dataframe to map!
    outputData(updated)
    
    #tells the user what changed
    report <- paste0(input$canvassers, " canvassers sent to ", input$precinctSelection, ", to knock on ",
                     round((input$canvassers * avgResourceReach), 0), " doors, activating ", activatedDems, " voters!")
    warnings(report)
  })
  
  ### WHAT HAPPENS WHEN THEY HIT RESET ##
  
  #simply passes outputData the original version of deSaulnier
  observeEvent(input$reset, {
    outputData(deSaulnier)
  })
  
  ### STAT OUTPUT SECTION ###
  
  #determines that the stats will be reactive to any changes in outputData
  summaryStats <- reactive({
    curr <- outputData()
    
    #saving stats to variables
    demVotes <- sum(curr$Dem)
    repVotes <- sum(curr$Rep)
    winner <- ifelse(
      demVotes > repVotes,
      "Democratic Victory",
      "Republican Victory"
    )
    
    #saves this all to a list that can be referenced later
    list(
      demVotes = demVotes,
      repVotes = repVotes,
      winner = winner
    )
  })
  
  #sends the above generated stats to the sidepanel whenever they change
  output$summaryBox <- renderPrint({
    
    #calls summaryStats to get latest tallies
    stats <- summaryStats()
    
    #string that is being output
    cat(
      "Total Dem Votes in District: ", stats$demVotes, "\n",
      "Total Rep Votes in District: ", stats$repVotes, "\n",
      "Result: ", stats$winner
    )
  })
  
  ### USER MESSAGES SECTION ###
  #creates and sends whatever warning text exists to the bottom of the mainpanel
  #this is how the user knows what has changed
  
  output$warningText <- renderText({
    warnings()
    })
  
  observeEvent(warnings(), {
    output$warningText <- renderText({ warnings() })
  })
  
}

## WHERE THE MAGIC HAPPENS ##

# Run the application 
shinyApp(ui = ui, server = server)
