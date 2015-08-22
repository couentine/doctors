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

  $("#tab-bar a").click(function(e) {
    e.preventDefault();
    $(this).tab('show');
  });

  setupTermTooltips();

});

// TERM MESSAGE MAPPINGS

var termMessages = {
  "admin": "Group admins are able to create new badges, manage group membership and change "
    + "group settings.",
  "branding": "Branding features include custom logos in emails and the ability to define "
    + " custom words for 'expert' and 'learner'.",
  "community": "Community features include collaborative wiki pages and (COMING SOON) "
    + "group profile pages and group search.",
  "lifetime-hosting": "If you ever decide to cancel your paid subscription all of the awarded "
    + "badges and evidence will continue be hosted at no additional cost.",
  "membership-controls": "Closed groups can only be joined if a user is invited by an admin.",
  "one-badge-awarder": "The Solo plan only supports badges which are awarded by the admin.",
  "open-groups": "Open groups allow anyone to join. All badges and evidence in open groups "
    + "are public and indexed by search engines.",
  "privacy-controls": "Closed groups let admins to decide between three levels of privacy for "
    + "each badge and piece of required evidence: public, private and secret.",
  "sub-groups": "(COMING SOON) Sub-groups allow you to link multiple groups underneath your "
    + "primary group. This allows you to create separate collections of badges with "
    + "a single unified membership structure.",
  "teacher": "The Teacher plan only supports the creation and awarding of badges by a single "
    + "teacher.",
  "unlimited-badge-awarders": "Unlimited badge awarder plans support 3 different types of badge "
    + "awarding: awarding by admins, awarding by badge experts and awarding by a specific "
    + "list of users."
};

function setupTermTooltips() {
  $(".term").each(function() {
    var message;
    
    $(this).tooltip({
      title: termMessages[$(this).data("term")],
      placement: 'bottom',
      container: 'body'
    });
  });
}