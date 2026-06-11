local activeElevator = nil
local currentFloorId = nil
local isOpen = false
local spawnedCabin = nil

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
    currentFloorId = currentFloor
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
                    coords = vector3(floor.coords.x, floor.coords.y, floor.coords.z),
                    size = vector3(1.5, 1.5, 2.5),
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
                exports['qb-target']:AddBoxZone(zoneName, vector3(floor.coords.x, floor.coords.y, floor.coords.z), 1.5, 1.5, {
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
                    local floorCoords = vector3(floor.coords.x, floor.coords.y, floor.coords.z)
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
    cb("ok") -- NUI callback hemen kapatılmalı, tüm async iş thread'de yapılır!

    local elevatorName = data.elevator
    local floorId = data.floorId

    if not Config.Elevators[elevatorName] then return end

    local targetFloor = nil
    local currentIndex = 1
    local targetIndex = 1
    for idx, floor in ipairs(Config.Elevators[elevatorName].floors) do
        if floor.id == currentFloorId then
            currentIndex = idx
        end
        if floor.id == floorId then
            targetFloor = floor
            targetIndex = idx
        end
    end

    if not targetFloor then return end

    local travelDirection = "up"
    local floorPath = {}
    if targetIndex > currentIndex then
        travelDirection = "up"
        for i = currentIndex, targetIndex do
            local f = Config.Elevators[elevatorName].floors[i]
            table.insert(floorPath, f.label or f.id)
        end
    elseif targetIndex < currentIndex then
        travelDirection = "down"
        for i = currentIndex, targetIndex, -1 do
            local f = Config.Elevators[elevatorName].floors[i]
            table.insert(floorPath, f.label or f.id)
        end
    else
        table.insert(floorPath, targetFloor.label or targetFloor.id)
    end

    -- Tüm bekleme/animasyon işlemi kendi thread'inde çalışır
    Citizen.CreateThread(function()
        -- Fare odağını kapat (NUI paneli hâlâ görünüyor ama tıklanamaz)
        SetNuiFocus(false, false)

        -- JS: motor sesi ve LED animasyonu başlat
        SendNUIMessage({ action = "start_travel", floorId = floorId })
        Citizen.Wait(600)

        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)

        if Config.UseCutscene then
            -- ======== SİNEMATİK GEÇİŞ (CSS NUI Kabin Overlay + Oyun Kamerası) ========

            -- Hedef katın etiketini bul (NUI göstergesi için)
            local targetLabel = targetFloor.label or targetFloor.id

            -- Ekranı karart
            DoScreenFadeOut(500)
            Citizen.Wait(600)

            -- NUI panelini kapat (asansör buton paneli)
            closeElevatorUI()

            -- Kabin Merkez Koordinatları ve Ayarları (Prop'un haritada durduğu ana nokta)
            local baseX, baseY, baseZ = 0.0, 0.0, 0.0
            
            -- Oyuncunun kabin içindeki konumu (Zemin yüksekliği Z = -1.25)
            local playerCoords = vector3(baseX, baseY, baseZ - 1.25)
            local playerHeading = 180.0 -- Oyuncunun bakış yönü (Güneye doğru = 180.0)
            
            -- ============================================================
            -- KAMERA AÇISI AYARLARI (İstediğinizi aktif edip diğerini kapatabilirsiniz)
            -- ============================================================
            
            -- AÇI 1: CCTV / GÜVENLİK KAMERASI (Önerilen - Köşeden geniş açı ile aşağı bakar)
            local camCoords = vector3(baseX - 0.95, baseY - 0.95, baseZ + 0.85)
            local lookAtCoords = vector3(baseX, baseY + 0.1, baseZ - 0.25)
            local camFov = 76.0
            
            -- AÇI 2: KARŞIDAN SİNEMATİK BAKIŞ (Göz hizasından düz bakar - Aktif etmek için üsttekileri kapatıp alttakileri açın)
            -- local camCoords = vector3(baseX, baseY - 1.1, baseZ + 0.15)
            -- local lookAtCoords = vector3(baseX, baseY, baseZ - 0.05)
            -- local camFov = 58.0
            -- ============================================================

            -- Oyuncuyu kabinin içine yerleştir
            SetEntityCoords(ped, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
            SetEntityHeading(ped, playerHeading)
            FreezeEntityPosition(ped, true)

            -- Karakter idle animasyonu (doğal duruş)
            TaskStandStill(ped, -1)

            -- Kamera: Oyuncu/kabin önünde durup içeri bakan kamerayı ayarla
            local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0, camFov, false, 0)
            PointCamAtCoord(cam, lookAtCoords.x, lookAtCoords.y, lookAtCoords.z)
            SetCamActive(cam, true)
            RenderScriptCams(true, false, 0, true, true)
            ShakeCam(cam, "HAND_SHAKE", 0.03) -- Çok hafif sallantı

            -- Işıklandırma döngüsü (karakter karanlıkta kalmasın)
            local lighting = true
            Citizen.CreateThread(function()
                while lighting do
                    Citizen.Wait(0)
                    -- Üstten beyaz tavan lambası
                    DrawLightWithRange(baseX, baseY, baseZ + 1.15, 255, 255, 255, 5.0, 25.0)
                    -- Kameradan sıcak dolgu ışığı
                    DrawLightWithRange(camCoords.x, camCoords.y, camCoords.z, 255, 240, 215, 4.0, 15.0)
                    -- Arkadan rim ışığı
                    DrawLightWithRange(baseX, baseY + 0.8, baseZ + 0.5, 180, 200, 220, 3.0, 8.0)
                end
            end)

            -- NUI: CSS asansör kabini çerçevesini göster (Kat animasyonlu)
            SendNUIMessage({
                action = "show_cabin",
                floorPath = floorPath,
                direction = travelDirection,
                speed = Config.FloorTransitionSpeed or 1500
            })

            -- Ekranı aç - karakter CSS kabin çerçevesinin içinde görünecek
            Citizen.Wait(200)
            DoScreenFadeIn(700)

            -- Ara sahne süresi (Kat başına geçiş hızıyla hesaplanır, en az 3 saniye sürer)
            local floorCount = #floorPath - 1
            if floorCount < 1 then floorCount = 1 end
            local travelTime = floorCount * (Config.FloorTransitionSpeed or 1500)
            if travelTime < 3000 then
                travelTime = 3000
            end
            Citizen.Wait(travelTime)

            -- Ekranı karart
            DoScreenFadeOut(500)
            Citizen.Wait(600)

            -- Işık döngüsünü durdur
            lighting = false

            -- NUI kabin overlay'ini kapat
            SendNUIMessage({ action = "hide_cabin" })

            -- Kamerayı temizle
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(cam, false)

            -- Nihai hedefe ışınlan
            local c = targetFloor.coords
            SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
            SetEntityHeading(ped, c.w)

            -- Ekranı aç
            DoScreenFadeIn(700)
            Citizen.Wait(1000)

            -- Varış sesi ve bildirimi
            SendNUIMessage({ action = "arrived", floorId = floorId })
            Citizen.Wait(1200)
            FreezeEntityPosition(ped, false)
            ClearPedTasks(ped)

            TriggerEvent('chat:addMessage', {
                color = {0, 200, 0}, multiline = true,
                args = {"Asansör", getLocale("arrived") .. " (" .. targetFloor.name .. ")"}
            })
            return
        end

        -- ======== NORMAL GEÇİŞ (UseCutscene = false) ========
        ::normalTransition::
        DoScreenFadeOut(600)
        Citizen.Wait(800)

        local c = targetFloor.coords
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(ped, c.w)

        closeElevatorUI()
        Citizen.Wait(Config.TravelDuration or 3500)

        DoScreenFadeIn(700)
        SendNUIMessage({ action = "arrived", floorId = floorId })
        Citizen.Wait(1200)
        FreezeEntityPosition(ped, false)

        TriggerEvent('chat:addMessage', {
            color = {0, 200, 0}, multiline = true,
            args = {"Asansör", getLocale("arrived") .. " (" .. targetFloor.name .. ")"}
        })
    end)
end)

-- Tedbir Amaçlı Kaynak Durdurulduğunda NUI Kapat ve Kamerayı/Oyuncuyu Temizle
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            closeElevatorUI()
        end
        if spawnedCabin and DoesEntityExist(spawnedCabin) then
            DeleteObject(spawnedCabin)
        end
        RenderScriptCams(false, false, 0, true, true)
        DestroyAllCams(true)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
