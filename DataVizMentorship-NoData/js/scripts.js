(() => {
  const map = L.map('map').setView([37.8, -96], 4);

  // Add Stadia.StamenTonerLite tile layer
  // Not my code!
  L.tileLayer('https://tiles.stadiamaps.com/tiles/stamen_toner_lite/{z}/{x}/{y}{r}.png', {
  maxZoom: 20,
  attribution: '&copy; <a href="https://stadiamaps.com/">Stadia Maps</a>, ' +
          '&copy; <a href="https://openmaptiles.org/">OpenMapTiles</a>, ' +
          '&copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors'
  }).addTo(map);

  fetch('ccc_modified.geojson')
  .then(res => res.json())
  .then(geojson => {
      const geojsonLayer = L.geoJson(geojson, {
          style: feature => {
          // Scale the color based on DidNotVoteDemNPP
          const didNotVote = feature.properties.DidNotVoteDemNPP;
          const maxDidNotVote = Math.max(...geojson.features.map(feature => feature.properties.DidNotVoteDemNPP));
          const yellowValue = (didNotVote / maxDidNotVote) * 255
    
          // Create an RGB color where the intensity of yellow increases with DidNotVoteDemNPP
          const color = `rgb(${yellowValue}, ${yellowValue}, 0)`;  // Transition from black (0,0,0) to yellow (255,255,0)
    
          return {
            weight: 1,
            opacity: 1,
            color: 'black',
            dashArray: '0',
            fillOpacity: 0.7,
            fillColor: color  // Apply calculated color
            };
          },
          
          onEachFeature: (feature, layer) => {
                  // Add hover label (tooltip)
                  layer.bindTooltip(
                      `Precinct: ${feature.properties.Precinct} - ` +
                      `Untapped Dem Voters: ${feature.properties.DidNotVoteDemNPP} - ` +
                      `Canvasser Sent: ${feature.properties.NumCanvassers}`,
                      { sticky: true } // Makes the tooltip follow the mouse
                  );
                  layer.on('mouseover', function() {
                      this.openTooltip();
                  });
                  layer.on('mouseout', function() {
                      this.closeTooltip();
                  });

                  // When a precinct is clicked, update the dropdown
                  layer.on('click', function () {
                      const precinctInfo = feature.properties;
                      // Update the dropdown menu to select the clicked precinct
                      precinctSelect.value = precinctInfo.Precinct;
                      zoomToPrecinct(precinctInfo);  // Zoom to the clicked precinct
                  });
              }
      }).addTo(map);

      // Populate the dropdown with precinct names
      geojson.features.forEach(feature => {
              const precinctName = feature.properties.Precinct;
              const option = document.createElement('option');
              option.value = precinctName;
              option.textContent = precinctName;
              precinctSelect.appendChild(option);
          });

      // Event listener for precinct selection
      precinctSelect.addEventListener('change', (e) => {
              const selectedPrecinct = e.target.value;
              if (selectedPrecinct) {
                  zoomToPrecinct(selectedPrecinct);
              }
          });

      // zoom
      function zoomToPrecinct(precinctInfo) {
          calcPrecints(precinctInfo)

          document.querySelector('#map-info').innerHTML = `
              <h3>${precinctInfo.Precinct}</h3>
              <h4>Max allowed ${calcPrecints(precinctInfo)}</h4>
              <div>
                  ${precinctInfo.DemVoteShare}-
                  ${precinctInfo.PercVotersInPrecinct}-
                  ${precinctInfo.PrecinctVotes}
              </div>
          `
      }

      function calcPrecints(precinctInfo) {
          //Define the logic for the max precincts
          const sliderPrecints = document.getElementById('precinctSlider')                    
          const value_max = parseInt((parseInt(precinctInfo.DidNotVoteDemNPP) / 63) / 0.09)
          sliderPrecints.max = value_max
          sliderPrecints.value = 0


          document.querySelector(`.filter-message`).classList.add(`deactivate`)
          document.querySelector(`.info-box`).classList.add(`active`)

          return value_max
      }

      // Update the slider value
      function updateSliderValue(value) {
          const slider = document.getElementById("precinctSlider");
          const sliderValue = document.getElementById("sliderValue");

          // Set slider value and update text
          slider.value = Math.min(Math.max(value, 0), 20);
          sliderValue.textContent = slider.value;
      }

      // Update slider text value on input change
      document.getElementById("precinctSlider").addEventListener('input', function() {
          document.getElementById("sliderValue").textContent = this.value;
      });

      map.fitBounds(geojsonLayer.getBounds());
  })
  .catch(err => console.error("Error loading GeoJSON:", err));

  
})()