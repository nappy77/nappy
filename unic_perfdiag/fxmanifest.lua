fx_version 'cerulean'
game 'gta5'

author 'unic_perfdiag'
description 'Benchmark A/B para diagnosticar impacto de resources (maps/MLOs/UI) no FPS'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
