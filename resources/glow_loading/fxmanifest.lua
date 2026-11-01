-- Orange loading screen with mod credits. Replaces the Qbox recipe's "loadscreen" resource.
-- qbx_core closes it when the character menu is ready, which is why shutdown is manual.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

files {
    'html/index.html',
    'html/style.css',
    'html/credits.js',
    'html/app.js',
}

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'
