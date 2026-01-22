local resourceName = GetCurrentResourceName()

local state = {
    uiOpen = false,
    running = false,
    currentTest = nil,
    baseline = nil,
    results = {},
    stoppedResources = {},
    config = nil,
    status = 'idle',
    fixedLocationEnabled = false,
    fixedLocations = { A = nil, B = nil },
    activeLocation = 'A',
    pendingStart = false
}

local metrics = {
    fpsInstant = 0,
    fpsAvg = 0,
    frameTimeAvg = 0,
    spikes = 0
}

local function notifyNui(payload)
    if not state.uiOpen then
        return
    end
    SendNUIMessage(payload)
end

local function log(message)
    print(('[%s] %s'):format(resourceName, message))
end

local function buildSet(list)
    local set = {}
    for _, item in ipairs(list or {}) do
        set[item] = true
    end
    return set
end

local function getConfig()
    if state.config then
        return state.config
    end
    TriggerServerEvent('unic_perfdiag:server:requestConfig')
    return nil
end

RegisterNetEvent('unic_perfdiag:client:config', function(payload)
    if not payload or not payload.ok then
        log(payload and payload.error or 'Falha ao receber config')
        return
    end
    state.config = payload.config
    state.fixedLocationEnabled = state.config.defaultFixedLocationEnabled
    notifyNui({
        type = 'config',
        config = state.config,
        fixedLocationEnabled = state.fixedLocationEnabled,
        activeLocation = state.activeLocation
    })

    if state.pendingStart then
        state.pendingStart = false
        CreateThread(function()
            runBenchmark({
                sampleSeconds = state.config.defaultSampleSeconds,
                stabilizationSeconds = state.config.defaultStabilizationSeconds,
                cooldownSeconds = state.config.defaultCooldownSeconds,
                mapsOnly = state.config.defaultMapsOnly,
                group = 'all',
                groupMode = 'single',
                spikeThresholdMs = state.config.spikeThresholdMs
            })
        end)
    end
end)

local function getGroups()
    local groups = {}
    local groupSet = {}

    if state.config and state.config.groups then
        for groupName, _ in pairs(state.config.groups) do
            groupSet[groupName] = true
        end
    end

    if state.config and state.config.resources then
        for _, item in ipairs(state.config.resources) do
            if item.group and item.group ~= '' then
                groupSet[item.group] = true
            end
        end
    end

    for groupName, _ in pairs(groupSet) do
        table.insert(groups, groupName)
    end

    table.sort(groups)
    return groups
end

local function buildTestPlan(options)
    local config = state.config
    if not config then
        return {}
    end

    local ignoreSet = buildSet(config.ignoredResources)
    local protectedSet = buildSet(config.protectedResources)
    local filtered = {}

    for _, item in ipairs(config.resources or {}) do
        local isMapType = item.type == 'map' or item.type == 'mlo'
        if options.mapsOnly and not isMapType then
            goto continue
        end

        if options.group and options.group ~= 'all' and item.group ~= options.group then
            goto continue
        end

        if ignoreSet[item.name] or protectedSet[item.name] then
            goto continue
        end

        table.insert(filtered, item)

        ::continue::
    end

    if options.groupMode == 'bundle' then
        local grouped = {}
        for _, item in ipairs(filtered) do
            local groupName = item.group or 'ungrouped'
            grouped[groupName] = grouped[groupName] or { resources = {}, type = 'group', group = groupName }
            table.insert(grouped[groupName].resources, item.name)
        end

        local plan = {}
        for groupName, data in pairs(grouped) do
            table.insert(plan, {
                name = groupName,
                type = 'group',
                group = groupName,
                resources = data.resources,
                isGroup = true
            })
        end

        table.sort(plan, function(a, b)\n            return a.name < b.name\n        end)

        return plan
    end

    local plan = {}
    for _, item in ipairs(filtered) do
        table.insert(plan, {
            name = item.name,
            type = item.type,
            group = item.group or '',
            resources = { item.name },
            isGroup = false
        })
    end

    return plan
end

local function teleportToLocation(location)
    if not location then
        return
    end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, location.x, location.y, location.z, false, false, false)
    SetEntityHeading(ped, location.w or 0.0)
end

local function ensureFixedLocation()
    if not state.fixedLocationEnabled then
        return
    end

    local location = state.fixedLocations[state.activeLocation]
    if not location then
        return
    end

    teleportToLocation(location)
end

local function collectSample(durationSeconds, spikeThresholdMs, onProgress)
    local startTime = GetGameTimer()
    local frames = 0
    local totalMs = 0
    local spikes = 0

    while state.running and (GetGameTimer() - startTime) < (durationSeconds * 1000) do
        Wait(0)
        local frameTimeMs = GetFrameTime() * 1000
        frames = frames + 1
        totalMs = totalMs + frameTimeMs
        if frameTimeMs >= spikeThresholdMs then
            spikes = spikes + 1
        end

        if onProgress then
            onProgress(frames)
        end
    end

    if not state.running then
        return nil
    end

    local elapsedSeconds = (GetGameTimer() - startTime) / 1000
    local avgFps = frames / elapsedSeconds
    local avgFrameMs = totalMs / math.max(frames, 1)

    return {
        fps = avgFps,
        frameMs = avgFrameMs,
        spikes = spikes,
        duration = elapsedSeconds
    }
end

local function waitWithStatus(seconds, status)
    if seconds <= 0 then
        return
    end

    state.status = status
    notifyNui({ type = 'status', status = status })

    local remaining = seconds
    while state.running and remaining > 0 do
        notifyNui({ type = 'cooldown', remaining = remaining })
        Wait(1000)
        remaining = remaining - 1
    end
end

local function requestResourceToggle(action, resources)
    if #resources == 0 then
        return true
    end

    local completed = false
    local success = true
    local requestId = tostring(GetGameTimer()) .. tostring(math.random(1000, 9999))
    local toggleCallbacks = state.toggleCallbacks

    if not toggleCallbacks then
        toggleCallbacks = {}
        state.toggleCallbacks = toggleCallbacks
    end

    toggleCallbacks[requestId] = function(payload)
        if not payload or not payload.ok then
            success = false
        else
            if payload.results then
                for resource, result in pairs(payload.results) do
                    if result.ok then
                        if action == 'stop' then
                            state.stoppedResources[resource] = true
                        else
                            state.stoppedResources[resource] = nil
                        end
                    end
                end
            end
        end
        completed = true
    end

    TriggerServerEvent('unic_perfdiag:server:toggleResources', {
        action = action,
        resources = resources,
        requestId = requestId
    })

    local timeout = GetGameTimer() + (Config.ResourceControlTimeoutSeconds * 1000)
    while not completed and GetGameTimer() < timeout do
        Wait(100)
    end

    if not completed then
        success = false
    end

    return success
end

RegisterNetEvent('unic_perfdiag:client:toggleResult', function(payload)
    local requestId = payload and payload.requestId
    if not requestId then
        return
    end

    local toggleCallbacks = state.toggleCallbacks or {}
    local cb = toggleCallbacks[requestId]
    if cb then
        toggleCallbacks[requestId] = nil
        cb(payload)
    end
end)

local function buildResultRow(testItem, baseline, test)
    local deltaFps = test.fps - baseline.fps
    local deltaFrame = test.frameMs - baseline.frameMs

    return {
        resource = testItem.name,
        type = testItem.type,
        group = testItem.group or '',
        fpsBaseline = baseline.fps,
        fpsTest = test.fps,
        deltaFps = deltaFps,
        frameBaseline = baseline.frameMs,
        frameTest = test.frameMs,
        deltaFrame = deltaFrame,
        spikesBaseline = baseline.spikes,
        spikesTest = test.spikes
    }
end

local function updateResultsUi()
    notifyNui({
        type = 'results',
        baseline = state.baseline,
        results = state.results
    })
end

local function runBaseline(sampleSeconds, stabilizationSeconds, spikeThresholdMs)
    state.status = 'baseline'
    notifyNui({ type = 'status', status = 'baseline' })

    ensureFixedLocation()
    waitWithStatus(stabilizationSeconds, 'baseline-stabilizing')

    local baseline = collectSample(sampleSeconds, spikeThresholdMs)
    if not baseline then
        return nil
    end

    state.baseline = baseline
    updateResultsUi()
    return baseline
end

local function runBenchmark(options)
    if state.running then
        return
    end

    state.running = true
    state.results = {}
    state.stoppedResources = {}

    local sampleSeconds = options.sampleSeconds
    local stabilizationSeconds = options.stabilizationSeconds
    local cooldownSeconds = options.cooldownSeconds
    local spikeThresholdMs = options.spikeThresholdMs

    local list = buildTestPlan({
        mapsOnly = options.mapsOnly,
        group = options.group,
        groupMode = options.groupMode
    })

    notifyNui({
        type = 'benchmarkStart',
        list = list
    })

    local baseline = runBaseline(sampleSeconds, stabilizationSeconds, spikeThresholdMs)
    if not baseline then
        state.running = false
        return
    end

    for _, testItem in ipairs(list) do
        if not state.running then
            break
        end

        state.currentTest = testItem.name
        state.status = ('testando %s'):format(testItem.name)
        notifyNui({ type = 'status', status = state.status })

        ensureFixedLocation()
        requestResourceToggle('stop', testItem.resources)

        waitWithStatus(stabilizationSeconds, 'test-stabilizing')
        local testSample = collectSample(sampleSeconds, spikeThresholdMs)

        requestResourceToggle('start', testItem.resources)
        waitWithStatus(cooldownSeconds, 'cooldown')

        if testSample then
            local row = buildResultRow(testItem, baseline, testSample)
            table.insert(state.results, row)
            updateResultsUi()
        end
    end

    state.running = false
    state.status = 'idle'
    state.currentTest = nil
    notifyNui({ type = 'status', status = 'idle' })
end

local function stopBenchmark()
    if not state.running then
        return
    end

    state.running = false

    local resources = {}
    for resource, _ in pairs(state.stoppedResources) do
        table.insert(resources, resource)
    end

    if #resources > 0 then
        requestResourceToggle('start', resources)
    end

    state.status = 'idle'
    notifyNui({ type = 'status', status = 'idle' })
end

local function buildExportData()
    local payload = {
        generatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        baseline = state.baseline,
        results = state.results
    }

    local json = json.encode(payload)
    local csvLines = {
        'resource,type,group,fps_baseline,fps_test,delta_fps,frametime_baseline,frametime_test,delta_frametime,spikes_baseline,spikes_test'
    }

    for _, row in ipairs(state.results) do
        table.insert(csvLines, string.format(
            '%s,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d',
            row.resource,
            row.type,
            row.group,
            row.fpsBaseline,
            row.fpsTest,
            row.deltaFps,
            row.frameBaseline,
            row.frameTest,
            row.deltaFrame,
            row.spikesBaseline,
            row.spikesTest
        ))
    end

    local csv = table.concat(csvLines, '\n')
    return json, csv
end

RegisterNetEvent('unic_perfdiag:client:exportResult', function(payload)
    if payload and payload.ok then
        notifyNui({
            type = 'exportSaved',
            jsonFile = payload.jsonFile,
            csvFile = payload.csvFile
        })
    else
        notifyNui({
            type = 'exportSaved',
            error = payload and payload.error or 'Falha ao exportar.'
        })
    end
end)

local function exportResults()
    local jsonData, csvData = buildExportData()
    notifyNui({ type = 'exportData', json = jsonData, csv = csvData })
    TriggerServerEvent('unic_perfdiag:server:saveExport', {
        json = jsonData,
        csv = csvData
    })
end

local function getPlayerLocation()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    return { x = coords.x, y = coords.y, z = coords.z, w = heading }
end

RegisterNUICallback('close', function(_, cb)
    state.uiOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('start', function(data, cb)
    if state.running then
        cb({ ok = false })
        return
    end

    local config = getConfig()
    if not config then
        cb({ ok = false })
        return
    end

    local options = {
        sampleSeconds = tonumber(data.sampleSeconds) or config.defaultSampleSeconds,
        stabilizationSeconds = tonumber(data.stabilizationSeconds) or config.defaultStabilizationSeconds,
        cooldownSeconds = tonumber(data.cooldownSeconds) or config.defaultCooldownSeconds,
        mapsOnly = data.mapsOnly == true,
        group = data.group or 'all',
        groupMode = data.groupMode or 'single',
        spikeThresholdMs = config.spikeThresholdMs
    }

    CreateThread(function()
        runBenchmark(options)
    end)

    cb({ ok = true })
end)

RegisterNUICallback('stop', function(_, cb)
    stopBenchmark()
    cb({ ok = true })
end)

RegisterNUICallback('export', function(_, cb)
    exportResults()
    cb({ ok = true })
end)

RegisterNUICallback('setLocation', function(data, cb)
    local slot = data and data.slot or 'A'
    state.fixedLocations[slot] = getPlayerLocation()
    notifyNui({ type = 'location', slot = slot, location = state.fixedLocations[slot] })
    cb({ ok = true })
end)

RegisterNUICallback('useLocation', function(data, cb)
    local slot = data and data.slot or 'A'
    state.activeLocation = slot
    notifyNui({ type = 'activeLocation', slot = slot })
    cb({ ok = true })
end)

RegisterNUICallback('toggleFixedLocation', function(data, cb)
    state.fixedLocationEnabled = data.enabled == true
    notifyNui({ type = 'fixedLocation', enabled = state.fixedLocationEnabled })
    cb({ ok = true })
end)

RegisterNUICallback('runBaselineCompare', function(data, cb)
    if state.running then
        cb({ ok = false })
        return
    end

    local config = getConfig()
    if not config then
        cb({ ok = false })
        return
    end

    local options = {
        sampleSeconds = tonumber(data.sampleSeconds) or config.defaultSampleSeconds,
        stabilizationSeconds = tonumber(data.stabilizationSeconds) or config.defaultStabilizationSeconds,
        spikeThresholdMs = config.spikeThresholdMs
    }

    CreateThread(function()
        state.running = true
        state.status = 'baseline-compare'
        notifyNui({ type = 'status', status = 'baseline-compare' })

        local resultA
        local resultB

        if state.fixedLocations.A then
            state.activeLocation = 'A'
            ensureFixedLocation()
            waitWithStatus(options.stabilizationSeconds, 'baseline-compare-A')
            resultA = collectSample(options.sampleSeconds, options.spikeThresholdMs)
        end

        if state.running and state.fixedLocations.B then
            state.activeLocation = 'B'
            ensureFixedLocation()
            waitWithStatus(options.stabilizationSeconds, 'baseline-compare-B')
            resultB = collectSample(options.sampleSeconds, options.spikeThresholdMs)
        end

        state.running = false
        state.status = 'idle'
        notifyNui({
            type = 'baselineCompare',
            resultA = resultA,
            resultB = resultB
        })
        notifyNui({ type = 'status', status = 'idle' })
    end)

    cb({ ok = true })
end)

RegisterCommand('perfdiag', function(_, args)
    local action = args[1]

    if action == 'start' then
        local config = getConfig()
        if config then
            CreateThread(function()
                runBenchmark({
                    sampleSeconds = config.defaultSampleSeconds,
                    stabilizationSeconds = config.defaultStabilizationSeconds,
                    cooldownSeconds = config.defaultCooldownSeconds,
                    mapsOnly = config.defaultMapsOnly,
                    group = 'all',
                    groupMode = 'single',
                    spikeThresholdMs = config.spikeThresholdMs
                })
            end)
        else
            state.pendingStart = true
        end
        return
    end

    if action == 'stop' then
        stopBenchmark()
        return
    end

    if action == 'export' then
        exportResults()
        return
    end

    state.uiOpen = true
    SetNuiFocus(true, true)
    getConfig()
    notifyNui({
        type = 'open',
        fixedLocationEnabled = state.fixedLocationEnabled,
        activeLocation = state.activeLocation,
        locations = state.fixedLocations,
        metrics = metrics,
        results = state.results,
        baseline = state.baseline,
        groups = getGroups()
    })
end)

RegisterKeyMapping('perfdiag', 'Abrir painel unic_perfdiag', 'keyboard', 'F9')

CreateThread(function()
    local frameCount = 0
    local totalMs = 0
    local spikes = 0
    local lastTick = GetGameTimer()
    local history = {}
    local windowSeconds = 5

    while true do
        Wait(0)
        local frameTimeMs = GetFrameTime() * 1000
        frameCount = frameCount + 1
        totalMs = totalMs + frameTimeMs
        if frameTimeMs >= Config.SpikeThresholdMs then
            spikes = spikes + 1
        end

        local now = GetGameTimer()
        if now - lastTick >= 1000 then
            table.insert(history, {
                frames = frameCount,
                totalMs = totalMs,
                spikes = spikes
            })

            if #history > windowSeconds then
                table.remove(history, 1)
            end

            local sumFrames = 0
            local sumMs = 0
            local sumSpikes = 0
            for _, item in ipairs(history) do
                sumFrames = sumFrames + item.frames
                sumMs = sumMs + item.totalMs
                sumSpikes = sumSpikes + item.spikes
            end

            metrics.fpsInstant = frameCount
            metrics.fpsAvg = sumFrames / math.max(#history, 1)
            metrics.frameTimeAvg = sumMs / math.max(sumFrames, 1)
            metrics.spikes = sumSpikes

            notifyNui({
                type = 'metrics',
                metrics = metrics
            })

            frameCount = 0
            totalMs = 0
            spikes = 0
            lastTick = now
        end
    end
end)
