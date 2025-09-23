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

// Apply plugin settings to a tab
function applyPluginSettingsToTab(tab) {
  function setOptions() {
    if (tab.yasr && tab.yasr.options) {
      tab.yasr.options.pluginOrder = ["table", "LeafletMap", "VisNetwork", "ChartJs", "response"];
      tab.yasr.options.defaultPlugin = "table";
    }
  }
  if (tab.yasr && tab.yasr.options) {
    setOptions();
  } else if (typeof tab.on === "function") {
    tab.on('yasrReady', () => {
      setOptions();
    });
  } else {
    console.warn("Tab object has no .on() method; cannot listen for yasrReady event");
  }
}

// Leaflet Map Plugin
class LeafletMapPlugin {
  priority = 10;
  hideFromSelection = false;
  label = 'Map';

  constructor(yasr) {
    this.yasr = yasr;
    this.container = document.createElement('div');
    this.container.className = 'yasr-plugin-container';
    this.mapDiv = document.createElement('div');
    this.mapDiv.className = 'fill';
    this.mapDiv.id = `map-${Math.random().toString(36).slice(2)}`;
    this.container.appendChild(this.mapDiv);
    this.map = null;
  }

  canHandleResults() {
    const vars = this.yasr.results.getVariables?.() || [];
    const hasLat = vars.some(v => ['lat','latitude','latDecimal','latDeg'].includes(v));
    const hasLon = vars.some(v => ['long','lon','longitude','longDecimal','longDeg'].includes(v));
    return hasLat && hasLon;
  }

  getIcon() {
    const el = document.createElement('span');
    return el;
  }

  draw() {
    this.yasr.resultsEl.innerHTML = '';
    this.yasr.resultsEl.appendChild(this.container);
    const { rows } = parseRowsFromYasr(this.yasr);
    if (!this.map) {
      this.map = L.map(this.mapDiv).setView([20, 0], 2);
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(this.map);
    }
    this.map.eachLayer(l => {
      if (l instanceof L.Marker || l instanceof L.CircleMarker || l instanceof L.GeoJSON) this.map.removeLayer(l);
    });
    const coords = [];
    rows.forEach(r => {
      const lat = parseFloat(r.lat || r.latitude || r.latDecimal || r.latDeg);
      const lon = parseFloat(r.long || r.lon || r.longitude || r.longDecimal || r.longDeg);
      if (isFinite(lat) && isFinite(lon)) {
        const label = r.label || r.name || r.s || '';
        const m = L.marker([lat, lon]).bindPopup(label);
        m.addTo(this.map);
        coords.push([lat, lon]);
      }
    });
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
    this.container = document.createElement('div');
    this.container.className = 'yasr-plugin-container';
    this.graphDiv = document.createElement('div');
    this.graphDiv.className = 'fill';
    this.graphDiv.id = `graph-${Math.random().toString(36).slice(2)}`;
    this.container.appendChild(this.graphDiv);
    this.network = null;
  }

  canHandleResults() {
    const vars = this.yasr.results.getVariables?.() || [];
    return (vars.includes('s') || vars.includes('subject')) &&
           (vars.includes('p') || vars.includes('predicate')) &&
           (vars.includes('o') || vars.includes('object'));
  }

  getIcon() {
    const el = document.createElement('span');
    return el;
  }

  draw() {
    this.yasr.resultsEl.innerHTML = '';
    this.yasr.resultsEl.appendChild(this.container);
    const { rows } = parseRowsFromYasr(this.yasr);
    const nodeMap = new Map();
    const edges = [];
    rows.forEach(r => {
      const s = r.s || r.subject;
      const p = r.p || r.predicate;
      const o = r.o || r.object;
      if (!s || !o) return;
      const sLabel = r.sLabel || r.subjectLabel || r.label || s;
      const oLabel = r.oLabel || r.objectLabel || r.label || o;
      if (!nodeMap.has(s)) nodeMap.set(s, { id: s, label: sLabel });
      if (!nodeMap.has(o)) nodeMap.set(o, { id: o, label: oLabel });
      edges.push({ from: s, to: o, label: p || '' });
    });
    const nodes = Array.from(nodeMap.values());
    const data = { nodes: new vis.DataSet(nodes), edges: new vis.DataSet(edges) };
    const options = {
      physics: { stabilization: true, barnesHut: { gravitationalConstant: -4000 } },
      edges: { arrows: 'to', smooth: { type: 'dynamic' } },
      interaction: { hover: true, tooltipDelay: 120 }
    };
    if (!this.network) {
      this.network = new vis.Network(this.graphDiv, data, options);
    } else {
      this.network.setData(data);
    }
  }
}

// Chart.js Plugin
class ChartJsPlugin {
  priority = 10;
  hideFromSelection = false;
  label = 'Chart';

  constructor(yasr) {
    this.yasr = yasr;
    this.container = document.createElement('div');
    this.container.className = 'yasr-plugin-container';
    this.canvas = document.createElement('canvas');
    this.canvas.className = 'fill';
    this.container.appendChild(this.canvas);
    this.chart = null;
  }

  canHandleResults() {
    const vars = this.yasr.results.getVariables?.() || [];
    const hasLabel = ['label','classLabel','category','bucket','name'].some(v => vars.includes(v));
    const hasValue = ['value','count','total','num'].some(v => vars.includes(v));
    return hasLabel && hasValue;
  }

  getIcon() {
    const el = document.createElement('span');
    return el;
  }

  draw() {
    this.yasr.resultsEl.innerHTML = '';
    this.yasr.resultsEl.appendChild(this.container);
    const { rows } = parseRowsFromYasr(this.yasr);
    const labels = rows.map(r => r.label || r.classLabel || r.category || r.bucket || r.name || '');
    const values = rows.map(r => Number(r.value || r.count || r.total || r.num || 0));
    if (this.chart) this.chart.destroy();
    this.chart = new Chart(this.canvas.getContext('2d'), {
      type: 'bar',
      data: { labels, datasets: [{ label: 'Count', data: values }] },
      options: { responsive: true, maintainAspectRatio: false }
    });
  }
}

// Register plugins
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
      if (key.startsWith('yasgui')) {
        localStorage.removeItem(key);
      }
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

// Main initialization on DOM ready
document.addEventListener("DOMContentLoaded", () => {
  console.log("Initializing Yasgui with endpoint:", endpointUrl);
  try {
    clearYasguiStorage();
    window.yasgui = new Yasgui(document.getElementById("yasgui"), {
      requestConfig: {
        endpoint: endpointUrl,
        method: "GET",
      },
      copyEndpointOnNewTab: false,
      persistence: false,
      persistenceId: null
    });

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

  // Handle dropdown query selection
  document.getElementById("exampleQueries").addEventListener("change", async (event) => {
    const queryName = event.target.value;
    if (!queryName) return;

    const query = await loadQueryFromFile(queryName);
    const newTab = window.yasgui.addTab(true);
    newTab.setEndpoint(endpointUrl);
    newTab.setQuery(query);
    
    // Set tab name based on the query
    const tabName = queryNames[queryName] || queryName;
    newTab.setName(tabName);
    applyPluginSettingsToTab(newTab);

    event.target.value = '';
  });
});
