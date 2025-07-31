# GeoNames project Documentation

This document summarizes important observations and disclaimers related to the GeoNames data dumps and ontologies.

---

## 1. Presence of `dcterms:modified` and Absence of `dcterms:created` in CSV Dumps

- In the GeoNames CSV dump files, the property `dcterms:created` does **not** appear in the CSV dumps.

---

## 2. Prefix `gn` Differences Across GeoNames RDF Files

- The GeoNames RDF files are not fully consistent in their use of HTTP vs HTTPS for the gn (GeoNames ontology) prefix.
- The ontology file (ontology_v3.3.rdf) uses the HTTPS namespace: https://www.geonames.org/ontology#
- The mappings file (mappings_v3.01.rdf) and place descriptions (about.rdf) use the HTTP namespace: http://www.geonames.org/ontology#

For consistency and security, our output uses the HTTPS form of the namespace as per the ontology file.

---

## 3. Inconsistencies in  properties

`gn:alternateName` 
- The property `gn:alternateName` is inconsistently used across GeoNames RDF data.
- Some `gn:alternateName` values lack language tags entirely.
- This affects whether alternate names are marked as German (`de`), English (`en`), etc or untagged.
- Due to source dataset inconsistencies, some variation in language tagging of alternate names remains unavoidable.


---

## 4. Handling Population Values of Zero

- Many GeoNames CSV dumps show a `population` value of `0` for numerous features, while the corresponding `about.rdf` files omit population when unknown.
- For example, [München (Uebigau-Wahrenbrück)](https://sws.geonames.org/2867711/) has population `0` in the CSV but no population in `about.rdf`, and Wikipedia reports around 16 residents.
- This suggests that `0` in CSV often means missing or incomplete data rather than no population.
- Therefore, **our Turtle output excludes `gn:population` triples when population equals `0`** to avoid misleading information.

---

*This documentation aims to clarify notable discrepancies in GeoNames datasets and ontology usage, facilitating consistent interpretation.

---

*Prepared based on inspection of:*  
- [GeoNames Ontology v3.3](https://www.geonames.org/ontology/ontology_v3.3.rdf)  
- [GeoNames Mappings v3.01](https://www.geonames.org/ontology/mappings_v3.01.rdf)  
- [GeoNames About RDF example](https://sws.geonames.org/3220837/about.rdf)  
- Local dump file: `geonames_DE.ttl`  
- GeoNames CSV dump data  

---
