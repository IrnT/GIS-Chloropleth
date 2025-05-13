const avgResourceReach = 62.5;
const chanceTurnout = 0.09;

let geoData;
let originalGeoData;
let map;
let precinctLayer;
let selectedPrecinct = null;

// Color scale function
function getColor(val) {
  const max = Math.max(...geoData.features.map(f => f.properties.DidNotVoteDemNPP));
  const min = 0;
  const ratio = (val - min) / (max - min);
  return `rgb(${Math.floor(255 * ratio)}, ${Math.floor(255 * ratio)}, 0)`;
}

function updateSummary() {
  const demVotes = geoData.features.reduce((sum, f) => sum + f.properties.Dem, 0);
  const repVotes = geoData.features.reduce((sum, f) => sum + f.properties.Rep, 0);
  const winner = demVotes > repVotes ? "Democratic Victory" : "Republican Victory";

  document.getElementById('summary').textContent =
    `Total Dem Votes: ${demVotes}\n` +
    `Total Rep Votes: ${repVotes}\n` +
    `Result: ${winner}`;
}

function drawMap() {
  if (precinctLayer) precinctLayer.remove();

  precinctLayer = L.geoJSON(geoData, {
    style: feature => ({
      color: "black",
      weight: 1,
      opacity: 1,
      fillOpacity: 0.75,
      fillColor: getColor(feature.properties.DidNotVoteDemNPP)
    }),
    onEachFeature: (feature, layer) => {
      layer.bindTooltip(`Precinct: ${feature.properties.Precinct}<br>
        Untapped Dem Voters: ${feature.properties.DidNotVoteDemNPP}<br>
        Canvassers Sent: ${feature.properties.NumCanvassers}`);
      layer.on('click', () => {
        selectedPrecinct = feature.properties.Precinct;
        document.getElementById('precinctSelect').value = selectedPrecinct;
      });
    }
  }).addTo(map);
}

function loadMap() {
  map = L.map('map').setView([37.9, -122.0], 10);
  L.tileLayer.provider("Stadia.StamenTonerLite").addTo(map);

  fetch('ccc_modified.geojson')
    .then(response => response.json())
    .then(data => {
      geoData = JSON.parse(JSON.stringify(data)); // deep copy
      originalGeoData = JSON.parse(JSON.stringify(data));
      drawMap();

      const select = document.getElementById('precinctSelect');
      geoData.features.forEach(f => {
        const opt = document.createElement("option");
        opt.value = f.properties.Precinct;
        opt.textContent = f.properties.Precinct;
        select.appendChild(opt);
      });
    });
}

function updateSliderValue(value) {
  const slider = document.getElementById("precinctSlider");
  const sliderValue = document.getElementById("sliderValue");

  // Clamp value between 0 and 20 and update slider + label
  slider.value = Math.min(Math.max(value, 0), 20);
  sliderValue.textContent = slider.value;
}


document.getElementById('canvasserRange').addEventListener('input', e => {
  document.getElementById('canvasserValue').textContent = e.target.value;
});

document.getElementById('sendBtn').addEventListener('click', () => {
  const precinct = document.getElementById('precinctSelect').value;
  const canvassers = parseInt(document.getElementById('canvasserRange').value);
  const activated = Math.round(canvassers * avgResourceReach * chanceTurnout);

  const feat = geoData.features.find(f => f.properties.Precinct === precinct);
  if (!feat) return;

  if (activated > feat.properties.DidNotVoteDemNPP) {
    document.getElementById('warnings').textContent =
      "Not enough Dems to activate. Try fewer canvassers or another precinct.";
    return;
  }

  feat.properties.NumCanvassers = canvassers;
  feat.properties.Dem += activated;
  feat.properties.DidNotVoteDemNPP -= activated;
  feat.properties.PrecinctVotes += activated;

  document.getElementById('warnings').textContent =
    `${canvassers} canvassers sent to ${precinct}, activating ${activated} voters!`;

  drawMap();
  updateSummary();
});

document.getElementById('resetBtn').addEventListener('click', () => {
  geoData = JSON.parse(JSON.stringify(originalGeoData));
  drawMap();
  updateSummary();
  document.getElementById('warnings').textContent = "";
});

loadMap();
