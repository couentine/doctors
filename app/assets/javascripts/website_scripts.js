$(document).ready(function() {

  $("[data-toggle=tooltip]").tooltip();

  if ($(".banner-row").length > 0) {
    $(window).scroll(function() {
      if ($(window).scrollTop() > $(".banner-row").height()) {
        $("#bl-navbar").switchClass("", "with-background", 300);
      } else {
        $("#bl-navbar").switchClass("with-background", "", 300);
      }
    });
  }

  $(".nav-tabs").tab();

});