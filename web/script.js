// Endpoint URL
const endpointUrl = `${window.location.origin}/sparql`;

// Default query
const defaultQuery = `SELECT * WHERE {
  ?s ?p ?o
} LIMIT 10`;

document.addEventListener("DOMContentLoaded", function () {
  console.log("Initializing Yasgui with endpoint:", endpointUrl);

  let yasgui;

  try {
    yasgui = new Yasgui(document.getElementById("yasgui"), {
      requestConfig: {
        endpoint: endpointUrl,
        method: "GET",
      },
      copyEndpointOnNewTab: false,
    });
    
    // Load default query
    // Set endpoint on current tab
    const tab = yasgui.getTab();
    tab.setEndpoint(endpointUrl); 
    tab.setQuery(defaultQuery);
  } catch (err) {
    console.error("Failed to initialize Yasgui:", err);
    return;
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
  });
});
