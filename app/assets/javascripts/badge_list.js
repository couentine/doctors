// This file includes site-wide javascript that will be loaded for all pages.


$(document).ready(function() {
    $('a[data-toggle=tooltip],span[data-toggle=tooltip],li[data-toggle=tooltip]').tooltip();
    disableLinks();
});

function disableLinks() {
  $('a[disabled=disabled]').click(function(event){
    //event.preventDefault(); // Prevent link from following its href
    return false;
  })
}