// Endpoint URL
const endpointUrl = "/sparql";

// Default query
const defaultQuery = `SELECT * WHERE {
  ?s ?p ?o
} LIMIT 10`;

document.addEventListener("DOMContentLoaded", function () {
  const yasgui = new Yasgui(document.getElementById("yasgui"), {
    requestConfig: {
      endpoint: endpointUrl,
      method: "GET",
    },
    copyEndpointOnNewTab: false,
  });

  // Load default query
  yasgui.getTab().setQuery(defaultQuery);

  // Load example queries from /queries/*.rq
  async function loadQueryFromFile(queryName) {
    try {
      const response = await fetch(`queries/${queryName}.rq`);
      if (!response.ok) throw new Error(`Failed to load query: ${response.status}`);
      return await response.text();
    } catch (error) {
      return `# Error loading query: ${error.message}\n${defaultQuery}`;
    }
  }

// Handle dropdown query selection
document.getElementById("exampleQueries").addEventListener("change", async (event) => {
  const queryName = event.target.value;
  if (!queryName) return;

  try {
    const query = await loadQueryFromFile(queryName);
    // Instead of replacing current tab, open a new one with that query
    yasgui.addTab(true).setQuery(query);
  } catch (error) {
    yasgui.addTab(true).setQuery(
      `# Error: Could not load query "${queryName}"\n${defaultQuery}`
    );
  }
});
});
