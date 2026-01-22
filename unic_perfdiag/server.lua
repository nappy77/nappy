local resourceName = GetCurrentResourceName()

local function buildSet(list)
    local set = {}
    for _, item in ipairs(list or {}) do
        set[item] = true
    end
    return set
end

local protectedSet = buildSet(Config.ProtectedResources)
local ignoredSet = buildSet(Config.IgnoredResources)

local function hasPermission(source)
    if source == 0 then
        return true
    end
    return IsPlayerAceAllowed(source, Config.AcePermission)
end

local function log(message)
    print(('[%s] %s'):format(resourceName, message))
end

local function isProtected(resource)
    return protectedSet[resource] == true
end

local function isIgnored(resource)
    return ignoredSet[resource] == true
end

local function safeStartResource(resource)
    if isProtected(resource) then
        log(('Protegido, ignorando start: %s'):format(resource))
        return false
    end

    local state = GetResourceState(resource)
    if state == 'started' then
        return true
    end

    local started = StartResource(resource)
    if not started then
        log(('Falha ao iniciar resource: %s'):format(resource))
        return false
    end

    return true
end

local function safeStopResource(resource)
    if isProtected(resource) then
        log(('Protegido, ignorando stop: %s'):format(resource))
        return false
    end

    local state = GetResourceState(resource)
    if state ~= 'started' then
        return true
    end

    local stopped = StopResource(resource)
    if not stopped then
        log(('Falha ao parar resource: %s'):format(resource))
        return false
    end

    return true
end

RegisterNetEvent('unic_perfdiag:server:toggleResources', function(payload)
    local source = source
    if not hasPermission(source) then
        log(('Sem permissão para %s'):format(source))
        TriggerClientEvent('unic_perfdiag:client:toggleResult', source, {
            ok = false,
            error = 'Sem permissão ACE.',
            requestId = payload and payload.requestId
        })
        return
    end

    local action = payload and payload.action
    local resources = payload and payload.resources or {}
    local requestId = payload and payload.requestId
    local results = {}

    if action ~= 'stop' and action ~= 'start' then
        TriggerClientEvent('unic_perfdiag:client:toggleResult', source, {
            ok = false,
            error = 'Ação inválida.',
            requestId = requestId
        })
        return
    end

    for _, resource in ipairs(resources) do
        if isIgnored(resource) then
            results[resource] = { ok = true, skipped = true, reason = 'ignored' }
        elseif isProtected(resource) then
            results[resource] = { ok = false, skipped = true, reason = 'protected' }
        else
            if action == 'stop' then
                results[resource] = { ok = safeStopResource(resource) }
            else
                results[resource] = { ok = safeStartResource(resource) }
            end
        end
    end

    TriggerClientEvent('unic_perfdiag:client:toggleResult', source, {
        ok = true,
        results = results,
        action = action,
        requestId = requestId
    })

    if action == 'stop' then
        CreateThread(function()
            Wait(Config.ResourceControlTimeoutSeconds * 1000)
            for _, resource in ipairs(resources) do
                if not isProtected(resource) and not isIgnored(resource) then
                    local state = GetResourceState(resource)
                    if state == 'started' then
                        log(('Timeout: resource ainda iniciado após stop: %s'):format(resource))
                    end
                end
            end
        end)
    end

    if action == 'start' then
        CreateThread(function()
            Wait(Config.ResourceControlTimeoutSeconds * 1000)
            for _, resource in ipairs(resources) do
                if not isProtected(resource) and not isIgnored(resource) then
                    local state = GetResourceState(resource)
                    if state ~= 'started' then
                        log(('Timeout: resource não iniciou: %s'):format(resource))
                    end
                end
            end
        end)
    end
end)

RegisterNetEvent('unic_perfdiag:server:saveExport', function(payload)
    local source = source
    if not hasPermission(source) then
        TriggerClientEvent('unic_perfdiag:client:exportResult', source, {
            ok = false,
            error = 'Sem permissão ACE.'
        })
        return
    end

    local jsonData = payload and payload.json or ''
    local csvData = payload and payload.csv or ''
    local timestamp = os.date('%Y%m%d_%H%M%S')

    local jsonFile = ('perfdiag_%s.json'):format(timestamp)
    local csvFile = ('perfdiag_%s.csv'):format(timestamp)

    local jsonSaved = SaveResourceFile(resourceName, jsonFile, jsonData, -1)
    local csvSaved = SaveResourceFile(resourceName, csvFile, csvData, -1)

    log(('Export salvo: %s (%s), %s (%s)'):format(jsonFile, tostring(jsonSaved), csvFile, tostring(csvSaved)))

    TriggerClientEvent('unic_perfdiag:client:exportResult', source, {
        ok = true,
        jsonFile = jsonFile,
        csvFile = csvFile
    })
end)

RegisterNetEvent('unic_perfdiag:server:requestConfig', function()
    local source = source
    if not hasPermission(source) then
        TriggerClientEvent('unic_perfdiag:client:config', source, {
            ok = false,
            error = 'Sem permissão ACE.'
        })
        return
    end

    TriggerClientEvent('unic_perfdiag:client:config', source, {
        ok = true,
        config = {
            resources = Config.Resources,
            protectedResources = Config.ProtectedResources,
            ignoredResources = Config.IgnoredResources,
            defaultSampleSeconds = Config.DefaultSampleSeconds,
            defaultStabilizationSeconds = Config.DefaultStabilizationSeconds,
            defaultCooldownSeconds = Config.DefaultCooldownSeconds,
            defaultMapsOnly = Config.DefaultMapsOnly,
            spikeThresholdMs = Config.SpikeThresholdMs,
            defaultFixedLocationEnabled = Config.DefaultFixedLocationEnabled,
            groups = Config.Groups
        }
    })
end)
