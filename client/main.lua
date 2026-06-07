local activeElevator = nil
local currentFloorId = nil
local isOpen = false

-- Metin Çevirileri Yardımcısı
local function getLocale(key)
    local lang = Config.Locale or "tr"
    if Config.Locales[lang] and Config.Locales[lang][key] then
        return Config.Locales[lang][key]
    end
    return Config.Locales["tr"][key] or key
end

-- Klasik 3D Metin Çizim Fonksiyonu
local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 10, 10, 10, 150)
    ClearDrawOrigin()
end

-- NUI Kapatma tetikleyicisi
local function closeElevatorUI()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "close"
    })
end

-- NUI Açma tetikleyicisi
local function openElevatorUI(elevatorName, elevatorData, currentFloor)
    isOpen = true
    SetNuiFocus(true, true)
    
    local floorsList = {}
    for i, floor in ipairs(elevatorData.floors) do
        table.insert(floorsList, {
            id = floor.id,
            label = floor.label,
            name = floor.name
        })
    end

    SendNUIMessage({
        action = "open",
        elevator = elevatorName,
        title = elevatorData.title or getLocale("title_default"),
        floors = floorsList,
        currentFloor = currentFloor
    })
end

-- ==========================================
-- HEDEF SİSTEMLERİ (qb-target / ox_target)
-- ==========================================
Citizen.CreateThread(function()
    if not Config.UseTarget then return end

    if Config.TargetSystem == "ox" then
        for elevatorName, elevatorData in pairs(Config.Elevators) do
            for _, floor in ipairs(elevatorData.floors) do
                exports.ox_target:addBoxZone({
                    coords = vec3(floor.coords.x, floor.coords.y, floor.coords.z),
                    size = vec3(1.5, 1.5, 2.5),
                    rotation = floor.coords.w,
                    debug = false,
                    options = {
                        {
                            name = 'elevator_' .. elevatorName .. '_' .. floor.id,
                            icon = Config.TargetIcon,
                            label = getLocale("target_label"),
                            onSelect = function()
                                openElevatorUI(elevatorName, elevatorData, floor.id)
                            end
                        }
                    }
                })
            end
        end
    elseif Config.TargetSystem == "qb" then
        for elevatorName, elevatorData in pairs(Config.Elevators) do
            for _, floor in ipairs(elevatorData.floors) do
                local zoneName = "elevator_" .. elevatorName .. "_" .. floor.id
                exports['qb-target']:AddBoxZone(zoneName, vec3(floor.coords.x, floor.coords.y, floor.coords.z), 1.5, 1.5, {
                    name = zoneName,
                    heading = floor.coords.w,
                    debugPoly = false,
                    minZ = floor.coords.z - 1.0,
                    maxZ = floor.coords.z + 1.5,
                }, {
                    options = {
                        {
                            type = "client",
                            action = function()
                                openElevatorUI(elevatorName, elevatorData, floor.id)
                            end,
                            icon = Config.TargetIcon,
                            label = getLocale("target_label"),
                        },
                    },
                    distance = Config.InteractDistance
                })
            end
        end
    end
end)

-- ==========================================
-- KLASİK ETKİLEŞİM DÖNGÜSÜ (E Tuşu & 3D Text)
-- ==========================================
Citizen.CreateThread(function()
    if Config.UseTarget then return end

    local textUiOpen = false

    while true do
        local sleep = 750
        local playerPed = PlayerPedId()
        
        if not IsPedInAnyVehicle(playerPed, true) and not isOpen then
            local playerCoords = GetEntityCoords(playerPed)
            local nearby = false
            
            for elevatorName, elevatorData in pairs(Config.Elevators) do
                for _, floor in ipairs(elevatorData.floors) do
                    local floorCoords = vec3(floor.coords.x, floor.coords.y, floor.coords.z)
                    local dist = #(playerCoords - floorCoords)

                    if dist < Config.DrawDistance then
                        sleep = 0
                        nearby = true

                        -- Yere yumuşak parlayan marker çiz
                        DrawMarker(27, floorCoords.x, floorCoords.y, floorCoords.z - 0.98, 
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 
                            255, 255, 255, 80, false, true, 2, false, nil, nil, false
                        )

                        if dist < Config.InteractDistance then
                            if Config.UseOxLibTextUI then
                                if not textUiOpen then
                                    exports.ox_lib:showTextUI(getLocale("prompt"))
                                    textUiOpen = true
                                end
                            else
                                DrawText3D(floorCoords.x, floorCoords.y, floorCoords.z + 0.2, getLocale("prompt"))
                            end

                            if IsControlJustReleased(0, Config.InteractKey) then
                                if textUiOpen then
                                    exports.ox_lib:hideTextUI()
                                    textUiOpen = false
                                end
                                openElevatorUI(elevatorName, elevatorData, floor.id)
                            end
                        else
                            if textUiOpen and dist > Config.InteractDistance then
                                exports.ox_lib:hideTextUI()
                                textUiOpen = false
                            end
                        end
                    end
                end
            end

            if not nearby and textUiOpen then
                exports.ox_lib:hideTextUI()
                textUiOpen = false
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- ==========================================
-- NUI GERİ BİLDİRİMLERİ (NUI Callbacks)
-- ==========================================
RegisterNUICallback("close", function(data, cb)
    closeElevatorUI()
    cb("ok")
end)

RegisterNUICallback("select_floor", function(data, cb)
    local elevatorName = data.elevator
    local floorId = data.floorId

    if Config.Elevators[elevatorName] then
        local targetFloor = nil
        for _, floor in ipairs(Config.Elevators[elevatorName].floors) do
            if floor.id == floorId then
                targetFloor = floor
                break
            end
        end

        if targetFloor then
            -- Fare ve klavye odağını hemen al ki kullanıcı tekrar tıklayamasın,
            -- ancak NUI panelinin seyahat animasyonunu görmesi için paneli henüz kapatma!
            SetNuiFocus(false, false)
            
            -- JS tarafına seyahatin başladığını bildir (Uğultu başlayacak)
            SendNUIMessage({
                action = "start_travel",
                floorId = floorId
            })
            
            -- NUI hareket seslerinin ve ekran göstergelerinin başlaması için 600ms tanı
            Citizen.Wait(600)
            
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            
            DoScreenFadeOut(600)
            Citizen.Wait(800) -- Ekranın tamamen kararmasını bekle

            -- Işınlanma
            local c = targetFloor.coords
            SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
            SetEntityHeading(ped, c.w)

            -- Seyahat süresi simülasyonu
            local travelTime = Config.TravelDuration or 3500
            Citizen.Wait(travelTime)

            -- Ekranı tekrar aç
            DoScreenFadeIn(800)
            
            -- Arayüze ulaştığımızı bildir (Çan çalacak, yeni kat yeşil ışığı yanacak)
            SendNUIMessage({
                action = "arrived",
                floorId = floorId
            })

            -- Oyuncunun çan sesini duyması ve ekrandaki yeni kat parlamasını görmesi için 1200ms bekle
            Citizen.Wait(1200)

            -- Karakteri serbest bırak ve paneli kapat
            FreezeEntityPosition(ped, false)
            closeElevatorUI()

            -- Ulaştı sohbet bildirimi
            TriggerEvent('chat:addMessage', {
                color = { 0, 200, 0},
                multiline = true,
                args = {"Asansör", getLocale("arrived") .. " (" .. targetFloor.name .. ")"}
            })
        end
    end
    cb("ok")
end)

-- Tedbir Amaçlı Kaynak Durdurulduğunda NUI Kapat
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            closeElevatorUI()
        end
    end
end)
