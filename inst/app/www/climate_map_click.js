// Report user clicks on county polygons. ggiraph's selection input also
// changes when a widget is rebuilt, so it cannot identify a real click.
document.addEventListener("click", function (event) {
  if (!(event.target instanceof Element)) {
    return;
  }

  const polygon = event.target.closest("path[data-id]");
  if (!polygon) {
    return;
  }

  const output = polygon.closest('[id$="-rainfall_map"], [id$="-vegetation_map"]');
  const match = output && output.id.match(/^(.+)-(rainfall|vegetation)_map$/);
  const countyId = polygon.getAttribute("data-id");
  if (!match || !/^KE\d{3}$/.test(countyId) || !window.Shiny) {
    return;
  }

  Shiny.setInputValue(match[1] + "-map_clicked", countyId, {
    priority: "event"
  });
});
