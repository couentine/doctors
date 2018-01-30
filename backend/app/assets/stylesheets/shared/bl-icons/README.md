# Badge List Icons #

These are built with the IcoMoon app.

They are used in the polymer frontend with the syntax `<i class='icon-home'></i>`. To see a list of all icons browse to `/a/icons` in the app.


In order to add new icons you need to...

1. Open IcoMoon (You can use `selection.json` in this folder to initialize the selection again if needed.), add files to the project and and re-export them to a font.
2. Expand the downloaded zip file
3. Copy the files to the right places: Fonts go in the fonts subfolder of this one, selection.json goes in this folder
4. Do not copy the style.css file directly in. You'll need to only copy the part from the `i` class down (from the style.css in the downloaded zip to the style.css.scss file in this folder). Also... the rest of the style.css.scss file is only there because the icons admin page needs it. (This is all kind of janky and needs refactoring eventually.)
5. Then manually diff the styles with `/frontend/app/src/bl-styles/bl-styles.html`
6. Then manually update `icons.html.erb`

OR instead of doing all that, just rebuilt a better icon demo engine that doesn't require all this jankiness. 