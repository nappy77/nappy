Config = {}

-- Permissão ACE necessária para controlar o benchmark (server-side)
Config.AcePermission = 'unic.perfdiag'

-- Recursos protegidos: NUNCA serão desligados
Config.ProtectedResources = {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-spawn',
    'qb-smallresources',
    'qb-hud',
    'oxmysql',
    'ox_lib',
    'pma-voice'
}

-- Recursos ignorados: não serão testados (mas podem ser protegidos também)
Config.IgnoredResources = {
    'chat',
    'spawnmanager',
    'sessionmanager',
    'hardcap'
}

-- Configuração padrão do benchmark
Config.DefaultSampleSeconds = 30
Config.DefaultStabilizationSeconds = 8
Config.DefaultCooldownSeconds = 4
Config.SpikeThresholdMs = 35 -- frametime acima disso conta como spike

-- Se true, o benchmark filtra por mapas/MLOs por padrão
Config.DefaultMapsOnly = true

-- Timeout de segurança ao parar/iniciar resources (server)
Config.ResourceControlTimeoutSeconds = 6

-- Modo de localização fixa
Config.DefaultFixedLocationEnabled = false

-- Exemplo de resources para teste (10 maps/MLOs fictícios)
-- type: "map" | "mlo" | "script"
-- group: permite desligar vários em conjunto
Config.Resources = {
    { name = 'mlo_legion_square', type = 'mlo', group = 'all_mlos_1' },
    { name = 'mlo_pillbox_hospital', type = 'mlo', group = 'all_mlos_1' },
    { name = 'mlo_blaine_sheriff', type = 'mlo', group = 'all_mlos_1' },
    { name = 'map_sandy_airfield', type = 'map', group = 'all_maps_1' },
    { name = 'map_grapeseed_farm', type = 'map', group = 'all_maps_1' },
    { name = 'map_chumash_docks', type = 'map', group = 'all_maps_1' },
    { name = 'mlo_vinewood_club', type = 'mlo', group = 'all_mlos_2' },
    { name = 'mlo_paleto_bank', type = 'mlo', group = 'all_mlos_2' },
    { name = 'ui_big_nui_demo', type = 'script', group = 'ui_suite_1' },
    { name = 'mlo_arcade_retro', type = 'mlo', group = 'all_mlos_2' }
}

-- Grupos explícitos (opcional). Se vazio, será derivado de Config.Resources
Config.Groups = {
    -- ['all_mlos_1'] = { 'mlo_legion_square', 'mlo_pillbox_hospital', 'mlo_blaine_sheriff' },
    -- ['all_maps_1'] = { 'map_sandy_airfield', 'map_grapeseed_farm', 'map_chumash_docks' },
    -- ['ui_suite_1'] = { 'ui_big_nui_demo' }
}
