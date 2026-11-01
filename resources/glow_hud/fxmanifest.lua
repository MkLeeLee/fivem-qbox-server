-- Glowing orange HUD for Qbox: status bars, speedometer, flight instruments, location.
-- Replaces qbx_hud, including its stress system and /cash and /bank commands.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
