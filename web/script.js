// Endpoint URL
const endpointUrl = "http://localhost:8080/sparql";

// SPARQL Queries
const queryAll = `
SELECT * WHERE {
  ?s ?p ?o
} LIMIT 10
`;

const queryPopulatedPlaces = `
PREFIX gn: <https://www.geonames.org/ontology#>
SELECT ?place ?name ?population
WHERE {
  ?place a gn:Feature ;
         gn:name ?name ;
         gn:population ?population .
  FILTER(?population > 10000)
}
LIMIT 10
`;

const querySameADM3 = `
PREFIX gn: <https://www.geonames.org/ontology#>
SELECT ?place ?name
WHERE {
  <https://sws.geonames.org/6558092/> gn:parentADM3 ?adm3 .
  ?place gn:parentADM3 ?adm3 ;
         gn:name ?name .
}
LIMIT 10
`;

// Default query to show on load
const defaultQuery = queryAll;

// Initialize Yasgui
const yasgui = new Yasgui(document.getElementById("yasgui"), {
  requestConfig: {
    endpoint: endpointUrl,
    method: 'GET' // avoid POST
  },
  copyEndpointOnNewTab: false,
});

// Scroll helper 
function scrollEditorToTop(tab) {
  setTimeout(() => {
    try {
      const cm = tab.getCodeMirror();
      if (cm) {
        if (typeof cm.scrollTo === "function") {
          cm.scrollTo(0, 0); // CodeMirror 5
        } else if (cm.scrollDOM) {
          cm.scrollDOM.scrollTop = 0; // CodeMirror 6
        } else if (cm.getScrollerElement) {
          cm.getScrollerElement().scrollTop = 0; // Fallback
        }
      }
    } catch (err) {
      console.warn("Could not scroll editor to top:", err);
    }
  }, 50);
}

// Load default query on page load
yasgui.getTab().setQuery(defaultQuery);
scrollEditorToTop(yasgui.getTab());

// Hook up example query buttons
document.querySelectorAll('.examples button').forEach(button => {
  button.addEventListener('click', () => {
    let query = '';
    switch (button.dataset.example) {
      case 'all':
        query = queryAll;
        break;
      case 'places':  
        query = queryPopulatedPlaces;
        break;
      case 'sameadm3':  
        query = querySameADM3;
        break;
      default:
        query = defaultQuery;
    }
    yasgui.getTab().setQuery(query);
    scrollEditorToTop(yasgui.getTab());
  });
});