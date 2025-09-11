// Endpoint URL
const endpointUrl = `${window.location.origin}/sparql`;

// Default query
const defaultQuery = `SELECT * WHERE {
  ?s ?p ?o
} LIMIT 10`;

// Query name mapping
const queryNames = {
  'all': 'All Triples',
  'populated_places': 'Populated Places',
  'sameadm3': 'Same ADM3 Places',
  'cities': 'Cities List'
};

document.addEventListener("DOMContentLoaded", function () {
  console.log("Initializing Yasgui with endpoint:", endpointUrl);

  let yasgui;

  try {
    // Clear localStorage for YASGUI to prevent quota issues
    clearYasguiStorage();
    
    yasgui = new Yasgui(document.getElementById("yasgui"), {
      requestConfig: {
        endpoint: endpointUrl,
        method: "GET",
      },
      copyEndpointOnNewTab: false,
      // Disable persistence to prevent localStorage issues
      persistence: false,
      persistenceId: null
      
    });
    
    // Load default query
    // Set endpoint on current tab
    const tab = yasgui.getTab();
    tab.setEndpoint(endpointUrl); 
    tab.setQuery(defaultQuery);
    tab.setName('Default Query'); // Set initial tab name
  } catch (err) {
    console.error("Failed to initialize Yasgui:", err);
    return;
  }

  // Function to clear YASGUI storage
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

  // Load example queries from /queries/*.rq
  async function loadQueryFromFile(queryName) {
    try {
      const response = await fetch(`queries/${queryName}.rq`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.text();
    } catch (error) {
      console.error(`Failed to load query "${queryName}":`, error);
      return `# Error loading query: ${error.message}\n${defaultQuery}`;
    }
  }

  // Handle dropdown query selection
  document.getElementById("exampleQueries").addEventListener("change", async (event) => {
    const queryName = event.target.value;
    if (!queryName) return;

    const query = await loadQueryFromFile(queryName);
    const newTab = yasgui.addTab(true);
    newTab.setEndpoint(endpointUrl);
    newTab.setQuery(query);
    
    // Set tab name based on the query
    const tabName = queryNames[queryName] || queryName;
    newTab.setName(tabName);
    
    // Reset dropdown selection
    event.target.value = '';
  });
});
