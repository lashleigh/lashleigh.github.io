// Zoomed out map
var map = L.map('mapid').setView([8.233237111274565, -4.921875000000001], 3);

L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoibWFwYm94IiwiYSI6ImNpejY4NXVycTA2emYycXBndHRqcmZ3N3gifQ.rJcFIG214AriISLbB6B5aw', {
	maxZoom: 18,
	attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, ' +
		'<a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, ' +
		'Imagery © <a href="http://mapbox.com">Mapbox</a>',
	id: 'mapbox.light'
}).addTo(map);

var site = {{ site | jsonify }}
var books = {{ site.books | jsonify }}

var locations = {{ site.data.locations | jsonify }}

// The page takes almost half a second to load with the detailed countries,
// but it looks so much better that I'm inclined to say that it's worth it.
{% if jekyll.environment == 'production' %}
  var countries_file = "/assets/geojson/countries_detailed.json"
{% else %}
  var countries_file = "/assets/geojson/countries.json"
{% endif %}

// Set a default style for out the polygons will appear
var defaultStyle = {
    color: "#2262CC",
    weight: 2,
    opacity: 0.0,
    fillOpacity: 0.0,
    fillColor: "#2262CC"
};

var highlightStyle = {
    color: '#2262CC',
    weight: 3,
    opacity: 0.6,
    fillOpacity: 0.65,
    fillColor: '#2262CC'
};
// Define what happens to each polygon just before it is loaded on to
// the map. This is Leaflet's special way of goofing around with your
// data, setting styles and regulating user interactions.
var onEachFeature = function(feature, layer) {
    // All we're doing for now is loading the default style.
    // But stay tuned.
    layer.setStyle(defaultStyle);
    // Create a self-invoking function that passes in the layer
    // and the properties associated with this particular record.
    (function(layer, properties) {
      // Create a mouseover event
      layer._polygonId = feature.id;
      layer._iso_3166_2 = feature.properties.iso_3166_2;

      layer.on("click", function (e) {
        // Change the style to the highlighted version
        console.log(e)
      });

      // Close the "anonymous" wrapper function, and call it while passing
      // in the variables necessary to make the events work the way we want.
    })(layer, feature.properties);
};

var countryFeatureLayer = new L.GeoJSON.AJAX(countries_file, {
    // And link up the function to run when loading each feature
    onEachFeature: onEachFeature
});
// Finally, add the layer to the map.
map.addLayer(countryFeatureLayer);

// Add the GeoJSON to the layer. `boundaries` is defined in the external
// GeoJSON file that I've loaded in the <head> of this HTML document.
var stateFeatureLayer = new L.GeoJSON.AJAX("/assets/geojson/us_states.json", {
    // And link up the function to run when loading each feature
    onEachFeature: onEachFeature
});
// Finally, add the layer to the map.
map.addLayer(stateFeatureLayer);
