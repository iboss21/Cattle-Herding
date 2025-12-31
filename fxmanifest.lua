fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'iboss21'
description 'tlw_cattle_herding - Professional Cattle Ranching System for RedM/RSG-Core'
version '2.0.0'
lua54 'yes'

-- Shared configuration
shared_scripts {
    'config.lua',
    'shared/utils.lua'
}

-- Client scripts
client_scripts {
    'client/main.lua',
    'client/controls.lua',
    'client/nui.lua'
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua', -- MySQL wrapper
    'server/db.lua',
    'server/prices.lua',
    'server/main.lua'
}

-- NUI files
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/app.js',
    'web/style.css',
    'web/assets/*.png',
    'web/assets/*.jpg',
    'web/assets/*.svg'
}

-- Dependencies
dependencies {
    'rsg-core',
    'oxmysql'
}
