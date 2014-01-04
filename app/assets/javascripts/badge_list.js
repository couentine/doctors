// This file includes site-wide javascript that will be loaded for all pages.


$(document).ready(function() {
    checkForTooltips();
    disableLinks();
    initializeDynamicColumns();
    checkDynamicColumns();
    checkResponsiveFormatting();
    checkForLocationHash();
    registerLocationHashEvents();
    registerAllRichTextAreas();
    createCharacterCounts();

    $(window).on('resize', function() {
      if (hasDynamicColumns) checkDynamicColumns();
      checkResponsiveFormatting();
    });
});

function checkForTooltips() {
  $('a[data-toggle=tooltip],span[data-toggle=tooltip],li[data-toggle=tooltip]').tooltip();
  $('a[rel=tooltip],span[rel=tooltip],li[rel=tooltip]').tooltip();
}

function disableLinks() {
  $('a[disabled=disabled]').click(function(event){
    //event.preventDefault(); // Prevent link from following its href
    return false;
  })
}

/* === CHARACTER COUNTS === */

function createCharacterCounts() {
  var maxLengh;
  $("textarea[data-character-count=true]").each(function() {
    var remainingCharacters = $(this).attr('data-max-length') - $(this).val().length;
    var classText = "character-count";
    if (remainingCharacters < 0) classText += " negative";

    // Create the html elements
    $(this).wrap("<div class='character-count-wrap'></div>");
    $(this).after("<span class='" + classText + "'>" + remainingCharacters + "</span>");

    // Create the event attachment
    $(this).keyup(function() {
      var remainingCharacters = $(this).attr('data-max-length') - $(this).val().length;
      $(this).siblings('.character-count').text(remainingCharacters);
      
      if (remainingCharacters < 0) $(this).siblings('.character-count').addClass('negative');
      else $(this).siblings('.character-count').removeClass('negative');
    });
  });
}

/* === RICH TEXT AREAS === */

// Registers rich text areas with wysihtml5
var wysihtml5ParserRules = {
  tags: { h3: {}, strong: {}, b: {}, i: {}, em: {}, br: {}, p: {}, ul: {}, ol: {}, li: {} }
};

function registerAllRichTextAreas() {
  if ($('#rich-text-toolbar').length > 0) {  
    var richTextToolbar = $('#rich-text-toolbar').first();
    var newToolbar;

    // First go through and clone / create the toolbars
    $('textarea.rich-text-area,textarea.modal-rich-text-area').each(function() { 
      newToolbar = $(richTextToolbar).clone();
      newToolbar.attr('id', $(this).attr('id')+"_toolbar");
      $(this).before(newToolbar);
    });

    // Then register the static text areas / register an event for the modal ones
    $('textarea.rich-text-area').each(function() { registerRichTextArea(this); });
    $('.modal').on('shown', function (e) { findAndRegisterModalRichTextAreas(this); })
  }
}

function findAndRegisterModalRichTextAreas(modalDiv) {
  $(modalDiv).find('textarea.modal-rich-text-area').each(function() {
    registerRichTextArea(this);
  });
}

function registerRichTextArea(textAreaElement) {
  var myId = $(textAreaElement).attr('id');

  var editor = new wysihtml5.Editor(myId, {
    toolbar: myId + "_toolbar",
    parserRules: wysihtml5ParserRules,
    autoLink: false,
    useLineBreaks: true,
    cleanUp: true
  });
}



// Checks for something like "/group-url#admins" and tries to show the "admins" tab or modal
function checkForLocationHash() {
  // Javascript to enable link to tab
  var url = document.location.toString();
  
  if (url.match('#')) {
    var header = url.split('#')[1];
    if ($('.nav-tabs a[href=#'+header+']').length > 0) {
      $('.nav-tabs a[href=#'+header+']').tab('show');
    } else if ($('#'+header).length > 0) {
      $('#'+header).modal('show');
      $('#'+header).find('textarea.modal-rich-text-area').each(function() {
        registerRichTextArea(this);
      });
    }
  } 
}

// Changes the location hash when modals & tabs are toggled
function registerLocationHashEvents() {
  // Tabs
  $('.nav-tabs a').on('shown', function (e) {
    var scrollTop = $(document).scrollTop();
    window.location.hash = e.target.hash; 
    $(document).scrollTop(scrollTop);
  })

  // Modals (Set on show, clear on hide)
  $('.modal').on('shown', function (e) {
    var scrollTop = $(document).scrollTop();
    window.location.hash = e.target.id;
    $(document).scrollTop(scrollTop);
  })
  $('.modal').on('hidden', function (e) { window.location.hash = ''; })
  
}


/* === CUSTOM RESPONSIVE REFORMATTING === */

// This checks to see if any of our custom responsive formatting code needs to be run
function checkResponsiveFormatting() {
  if (($("#subheader").length > 0) && ($("#subheader ul.breadcrumb").length > 0)) {
    var availableWidth = $("#subheader").width()-90;

    // First check if we're actually out of space
    if (($("#subheader ul.breadcrumb").width() + $("ul.subheader-actions").width()) > availableWidth) {
      // Sub-header formatting (right side)
      if ($("ul.subheader-actions").width() > (availableWidth*0.3)) {
        var newHTMLContent; var textContent;
        
        $("ul.subheader-actions li.collapsible, ul.subheader-actions li.collapsible div.dropdown")
          .children('a').each(function() {
          
          textContent = $(this).text().trim();
          newHTMLContent = "";
          
          // Run through each node and extract HTML of only the non-text elements
          $(this).contents().each(function(){
            if (this.nodeType!=3)
              newHTMLContent += $(this).clone().wrap('<div>').parent().html(); 
          });

          // Clear out everything but html and recreate the text content as a tooltip
          $(this).html(newHTMLContent);
          $(this).tooltip({
            title: textContent,
            placement: 'bottom'
          });
        });
      }
      
      // Sub-header formatting (left side)
      availableWidth -= $("ul.subheader-actions").width();
      if ($("#subheader ul.breadcrumb").width() > availableWidth) {
        var theElement; var theText;
        var isDone = false;

        $("#subheader ul.breadcrumb li").each(function() {
          if ($(this).find("a").length > 0) theElement = $(this).find("a");
          else theElement = this;
          
          theText = $(theElement).text();
          if (!isDone && theText.length > 11) {
            $(theElement).tooltip({
              title: theText,
              placement: 'bottom'
            });
            $(theElement).text(theText.substring(0,5) + "..." + theText.substring(theText.length-3));

          }

          isDone = ($("#subheader ul.breadcrumb").width() < availableWidth);
        });
      }

    }
  }
}

/* === DYNAMIC COLUMNS FUNCTIONALITY === */

// dcThresholds stores the width thresholds (in pixels)
// If the width is GTE the threshold value at index i, then there will be i+1 columns
var dcThresholds = [1, 700, 980];
var dcGroups = {}; // each entry has the following subkeys: children, width, columns
var hasDynamicColumns = false;

function getTargetColCount(windowWidth) {
  var target;
  for (target=0; (dcThresholds[target]!=null) && (windowWidth>=dcThresholds[target]); target++) {}
  return target;
}

function initializeDynamicColumns() {
  var curKey;
  var curWidth;
  var curChildren;
  var dynamicColumnParents = $('div[data-bl-dyncol=parent]');
  hasDynamicColumns = (dynamicColumnParents.length > 0);

  if (hasDynamicColumns) {
    for (var i=0; i<dynamicColumnParents.length; i++) {
      curKey = $(dynamicColumnParents[i]).attr('data-bl-dyncol-group');
      curWidth = $(dynamicColumnParents[i]).attr('data-bl-dyncol-width');
      curChildren = $(dynamicColumnParents[i]).find('div[data-bl-dyncol=child]');
      dcGroups[curKey] = {
        width: curWidth,
        children: curChildren,
        columns: [dynamicColumnParents[i]]
      };
    }
  }
}

// This checks each DC group for a column mismatch and, when found, calls updateDynamicColumnGroup()
function checkDynamicColumns() {
  var targetColCount = getTargetColCount($(window).width());
  var curColCount;

  for (var key in dcGroups) {
    curColCount = dcGroups[key].columns.length;
    if (curColCount != targetColCount) {
      updateDynamicColumnGroup(key, targetColCount);
      checkForTooltips();
    }
  }
}

// Rebuilds the columns for the specified group with {targetColCount} columns
function updateDynamicColumnGroup(key, targetColCount) {
  var dcGroup = dcGroups[key];
  var addClass = 'span' + (dcGroup.width/targetColCount);
  var newColumn;
  
  // First empty out all of the columns
  for (var i in dcGroup.columns)
    $(dcGroup.columns[i]).empty().removeClass().addClass(addClass).addClass('dynamic-column');
  
  // Next we need to delete extra columns / create missing columns
  if (dcGroup.columns.length > targetColCount) {
    var removedColumns = dcGroup.columns.splice(targetColCount, 
                                                 dcGroup.columns.length - targetColCount);
    for (var i in removedColumns)
      $(removedColumns[i]).remove();
  } else if (dcGroup.columns.length < targetColCount) {
    // Basically we just clone the last item in the columns array
    for (var i=dcGroup.columns.length; i<targetColCount; i++) {
      newColumn = $(dcGroup.columns[i-1]).clone();
      $(dcGroup.columns[i-1]).after(newColumn);
      dcGroup.columns.push(newColumn);
    }
  }

  // Finally we run through the children and add them to the appropriate columns
  for (var i in dcGroup.children)
    $(dcGroup.columns[i % targetColCount]).append(dcGroup.children[i]);
}
