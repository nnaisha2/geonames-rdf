// Endpoint URL
const endpointUrl = document.getElementById("endpointInput")?.value || `${window.location.origin}/sparql`;

// Default query name (file to load)
const defaultQueryName = 'all';

// Query names mapping
const queryNames = {
  'all': 'All triples (limit 10)',
  'population': 'Municipalities with a population above 1 million',
  'municipalities': 'Municipalities in a rural district',
  'hierarchy': 'Administrative hierarchy above a city',
  'museums': 'Museums in a city',
  'graph_administrative_subdivisions': 'Administrative subdivisions (graph)'
};

// Utility function: Parses rows from Yasr result
function parseRowsFromYasr(yasr) {
  const vars = yasr.results.getVariables?.() || [];
  const bindings = yasr.results.getBindings?.() || [];
  const rows = bindings.map(b => {
    const r = {};
    vars.forEach(v => {
      if (b[v]) r[v] = b[v].value;
    });
    return r;
  });
  return { vars, rows };
}

// Function to set plugin options for a given YASR tab
function applyPluginSettingsToTab(tab) {
  function setOptions() {
    if (tab.yasr && tab.yasr.options) {
      tab.yasr.options.pluginOrder = ["table", "LeafletMap", "VisNetwork", "ChartJs", "response"];
      tab.yasr.options.defaultPlugin = "table";
    }
  }
  // If options are available now, set them immediately
  if (tab.yasr && tab.yasr.options) {
    setOptions();
  } else if (typeof tab.on === "function") {
    // Otherwise, wait until YASR is ready to apply them
    tab.on('yasrReady', () => {
      setOptions();
    });
  } else {
    console.warn("Tab object has no .on() method; cannot listen for yasrReady event");
  }
}

// Define a custom YASR plugin that displays results on a Leaflet map
class LeafletMapPlugin {
  priority = 10;
  hideFromSelection = false;
  label = 'Map';

  constructor(yasr) {
    this.yasr = yasr; // store YASR instance
    this.container = document.createElement('div');
    this.container.className = 'yasr-plugin-container';
    this.mapDiv = document.createElement('div');
    this.mapDiv.className = 'fill';
    // create a unique id for map element
    this.mapDiv.id = `map-${Math.random().toString(36).slice(2)}`;
    // append map div to container
    this.container.appendChild(this.mapDiv);
    this.map = null;
  }

  // Check if the result set can be shown as points on a map (must include latitude/longitude)
  canHandleResults() {
    const vars = this.yasr.results.getVariables?.() || [];
    const hasLat = vars.some(v => ['lat','latitude','latDecimal','latDeg'].includes(v)); // check for latitude field
    const hasLon = vars.some(v => ['long','lon','longitude','longDecimal','longDeg'].includes(v)); // check for longitude field
    return hasLat && hasLon; // return true only if both are present
  }

  getIcon() {
    const el = document.createElement('span'); // create an empty span as icon
    return el;
  }

  // Render method for displaying the map
  draw() {
    this.yasr.resultsEl.innerHTML = ''; // clear previous content
    this.yasr.resultsEl.appendChild(this.container);
    const { rows } = parseRowsFromYasr(this.yasr);
    // If map is not initialized yet, create it
    if (!this.map) {
      this.map = L.map(this.mapDiv).setView([20, 0], 2); // center map at (20,0) zoom 2
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(this.map);
    }
    // Remove all previously added markers to avoid duplicates
    this.map.eachLayer(l => {
      if (l instanceof L.Marker || l instanceof L.CircleMarker || l instanceof L.GeoJSON)
        this.map.removeLayer(l);
    });

    const coords = []; // array to store coordinates to fit map bounds

    // Loop through rows to create markers
    rows.forEach(r => {
      // try reading possible latitude/longitude variable names
      const lat = parseFloat(r.lat || r.latitude || r.latDecimal || r.latDeg);
      const lon = parseFloat(r.long || r.lon || r.longitude || r.longDecimal || r.longDeg);
      const uri = r.feature || r.uri || r.url || null; // URI for linked data
      const label = r.label || r.name || r.s || '';
      // Add marker only if lat and lon are valid numbers
      if (isFinite(lat) && isFinite(lon)) {
        const popupContent = uri ? `<a href="${uri}" target="_blank">${label}</a>` : label; // popup text
        const m = L.marker([lat, lon]).bindPopup(popupContent); // create Leaflet marker with popup

        // Enable click on marker to open URI in a new tab
        if (uri && /^https?:\/\//.test(uri)) {
          m.on('dblclick', () => window.open(uri, '_blank'));
        }

        m.addTo(this.map); // add marker to map
        coords.push([lat, lon]);
      }
    });
    // Adjust map to fit all markers on screen
    if (coords.length) this.map.fitBounds(L.latLngBounds(coords), { maxZoom: 8 });
    setTimeout(() => this.map.invalidateSize(), 0);
  }
}

// Vis Network Graph Plugin
class VisNetworkPlugin {
  priority = 10;
  hideFromSelection = false;
  label = 'Graph';

  constructor(yasr) {
    this.yasr = yasr;
    this.container = document.createElement('div'); // plugin container
    this.container.className = 'yasr-plugin-container';
    this.graphDiv = document.createElement('div'); // div for the visual graph
    this.graphDiv.className = 'fill';
    this.graphDiv.id = `graph-${Math.random().toString(36).slice(2)}`;
    this.container.appendChild(this.graphDiv); // append graph to container
    this.network = null;
  }

  // Determine if data has subject-predicate-object structure
  canHandleResults() {
    const vars = this.yasr.results.getVariables?.() || [];
    return (vars.includes('s') || vars.includes('subject')) &&
           (vars.includes('p') || vars.includes('predicate')) &&
           (vars.includes('o') || vars.includes('object'));
  }

  getIcon() {
    const el = document.createElement('span'); // empty span as icon
    return el;
  }

  // Renders the RDF graph visualization
  draw() {
  this.yasr.resultsEl.innerHTML = ''; // clear old result

  // Create container for the toggle UI and graph
  const toggleContainer = document.createElement('div');
  toggleContainer.style.marginBottom = '0.5em';

  // Create checkbox for showing/hiding edge labels
  const labelToggle = document.createElement('input');
  labelToggle.type = 'checkbox';
  labelToggle.id = 'edgeLabelToggle';
  labelToggle.checked = false; // default: labels hidden

  // Create label element for the checkbox
  const label = document.createElement('label');
  label.htmlFor = 'edgeLabelToggle';
  label.style.marginLeft = '0.4em';
  label.textContent = 'Show predicate (edge) labels';

  // Append checkbox and label to toggle container
  toggleContainer.appendChild(labelToggle);
  toggleContainer.appendChild(label);

  // Create container for the graph visualization
  this.yasr.resultsEl.appendChild(toggleContainer);
  this.yasr.resultsEl.appendChild(this.container);

  const renderGraph = (showEdgeLabels) => {
    const { rows } = parseRowsFromYasr(this.yasr); // extract rows
    const nodeMap = new Map();
    const edges = [];
    rows.forEach(r => {
      const s = r.s || r.subject; // Retrieve subject URI or identifier
      const p = r.pLabel || r.predicateLabel || r.p || r.predicate || '';
      const o = r.o || r.object;
      if (!s || !o) return; // Skip this row if subject or object missing

      const sLabel = r.sLabel || r.subjectLabel || s;  // Label for subject node (fallback: URI)
      const oLabel = r.oLabel || r.objectLabel || o;
      
      // Add subject node to node map if it doesn’t already exist
      if (!nodeMap.has(s)) nodeMap.set(s, { id: s, label: sLabel });
      if (!nodeMap.has(o)) nodeMap.set(o, { id: o, label: oLabel });

      // Add an edge between subject and object, optionally showing predicate as label
      edges.push({ from: s, to: o, label: showEdgeLabels ? p : '' });
    });
     // Convert Map entries into an array suitable for Vis.js DataSet
    const nodes = Array.from(nodeMap.values());
    const data = { nodes: new vis.DataSet(nodes), edges: new vis.DataSet(edges) };

    const options = {
      physics: { stabilization:false, barnesHut: { gravitationalConstant: -4000 } },
      edges: { arrows: 'to', smooth: { type: 'dynamic' } },
      interaction: { hover: true, tooltipDelay: 120 }
    };

    if (!this.network) {
      this.network = new vis.Network(this.graphDiv, data, options);
    } else {
      this.network.setData(data);
    }
  };

  // Initial render with edge labels hidden
  renderGraph(false);

  // Add event listener to toggle checkbox to rerender graph on change
  labelToggle.addEventListener('change', (event) => {
    renderGraph(event.target.checked);
  });
}
}

// Chart.js Plugin
class ChartJsPlugin {
  priority = 10;
  hideFromSelection = false;
  label = 'Chart';

  constructor(yasr) {
    this.yasr = yasr;
    this.container = document.createElement('div'); // create outer container
    this.container.className = 'yasr-plugin-container';
    this.canvas = document.createElement('canvas'); // create <canvas> for chart
    this.canvas.className = 'fill';
    this.container.appendChild(this.canvas); // add canvas to container
    this.chart = null;
  }

  // Check if results contain both a label-type field and numeric values
  canHandleResults() {
    const vars = this.yasr.results.getVariables?.() || [];
    const hasLabel = ['label','classLabel','category','bucket','name'].some(v => vars.includes(v));
    const hasValue = ['value','count','total','num'].some(v => vars.includes(v));
    return hasLabel && hasValue;
  }

  getIcon() {
    const el = document.createElement('span'); // return empty span
    return el;
  }

  // Render the chart
  draw() {  
  // Clear the existing results in the YASR results container  
  this.yasr.resultsEl.innerHTML = '';  
  this.yasr.resultsEl.appendChild(this.container);  
  const { rows } = parseRowsFromYasr(this.yasr);  

  // Generate an array of labels, using the first available field from each row or empty string  
  const labels = rows.map(r => r.label || r.classLabel || r.category || r.bucket || r.name || '');  

  // Generate an array of numeric values from row fields, defaulting to 0 if missing  
  const values = rows.map(r => Number(r.value || r.count || r.total || r.num || 0));  

  // Determine the chart's legend label: first row's legendLabel → default "Count"  
  const legendLabel =   
      rows[0]?.legendLabel ||  
      'Count';  

  // Destroy the existing chart instance to avoid drawing over it  
  if (this.chart) this.chart.destroy();  

  // Create a new Chart.js bar chart
  this.chart = new Chart(this.canvas.getContext('2d'), {  
    type: 'bar', // Chart type is set to bar  
    data: {  
      labels, // X-axis labels  
      datasets: [{ label: legendLabel, data: values }] // Y-axis dataset with legend label and values  
    },  
    options: {  
      responsive: true, // Chart resizes dynamically
      maintainAspectRatio: false // Allows chart to adjust height independently of width  
    }  
  });  
}
}

// Register custom plugins with the Yasr library if not already done
if (window.Yasr && !Yasr._customPluginsRegistered) {
  Yasr.registerPlugin('LeafletMap', LeafletMapPlugin);
  Yasr.registerPlugin('VisNetwork', VisNetworkPlugin);
  Yasr.registerPlugin('ChartJs', ChartJsPlugin);
  Yasr._customPluginsRegistered = true;
}

// Clear YASGUI storage to prevent quota issues
function clearYasguiStorage() {
  try {
    Object.keys(localStorage).forEach(key => {
      if (key.startsWith('yasgui')) localStorage.removeItem(key); // remove stored YASGUI data
    });
    console.log('Cleared YASGUI localStorage items');
  } catch (e) {
    console.warn('Could not clear localStorage:', e);
  }
}

// Load query from file
async function loadQueryFromFile(queryName) {
  try {
    const response = await fetch(`queries/${queryName}.rq`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.text();
  } catch (error) {
    console.error(`Failed to load query "${queryName}":`, error);
    return `# Error loading query: ${error.message}\nSELECT * WHERE { ?s ?p ?o } LIMIT 10`;
  }
}

// Run initialization code once the page content is fully loaded
document.addEventListener("DOMContentLoaded", () => {
  console.log("Initializing Yasgui with endpoint:", endpointUrl);
  try {
    clearYasguiStorage(); // clear local storage entries
    window.yasgui = new Yasgui(document.getElementById("yasgui"), {
      requestConfig: {
        endpoint: endpointUrl,
        method: "GET",
      },
      copyEndpointOnNewTab: false,
      persistence: false,
      persistenceId: null
    });

    // Load and insert the default query as the first tab’s content
    loadQueryFromFile(defaultQueryName).then(defaultQueryText => {
      const defaultTab = window.yasgui.getTab();
      defaultTab.setEndpoint(endpointUrl); 
      defaultTab.setQuery(defaultQueryText);
      defaultTab.setName(queryNames[defaultQueryName] || 'Default Query');
      applyPluginSettingsToTab(defaultTab);
    });
  } catch (err) {
    console.error("Failed to initialize Yasgui:", err);
    return;
  }

  // event listener to query dropdown selector
  document.getElementById("exampleQueries").addEventListener("change", async (event) => {
    const queryName = event.target.value;
    if (!queryName) return; 

    const query = await loadQueryFromFile(queryName); // load chosen query
    const newTab = window.yasgui.addTab(true);
    newTab.setEndpoint(endpointUrl);
    newTab.setQuery(query);
    const tabName = queryNames[queryName] || queryName
    newTab.setName(tabName);
    applyPluginSettingsToTab(newTab);

    event.target.value = '';
  });
});