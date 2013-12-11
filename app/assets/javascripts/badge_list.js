// This file includes site-wide javascript that will be loaded for all pages.


$(document).ready(function() {
    checkForTooltips();
    disableLinks();
    initializeDynamicColumns();
    checkDynamicColumns();

    $(window).on('resize', function() {
      if (hasDynamicColumns) checkDynamicColumns();
    });
});

function checkForTooltips() {
  $('a[data-toggle=tooltip],span[data-toggle=tooltip],li[data-toggle=tooltip]').tooltip();
}

function disableLinks() {
  $('a[disabled=disabled]').click(function(event){
    //event.preventDefault(); // Prevent link from following its href
    return false;
  })
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