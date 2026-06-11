Config = {}

Config.Locale = "tr" -- Dil seçeneği ('tr' veya 'en')

Config.UseTarget = false -- ox_target veya qb-target entegrasyonu (true ise hedefler otomatik oluşturulur)
Config.TargetSystem = "ox" -- "ox" veya "qb" (UseTarget true ise etkindir)

Config.Use3DText = true -- Klasik 3D Metin gösterilsin mi? (UseTarget false ise)
Config.UseOxLibTextUI = false -- ox_lib TextUI kullanılsın mı? (ox_lib kuruluysa önerilir)

Config.DrawDistance = 5.0 -- 3D metnin görünme mesafesi
Config.InteractDistance = 2.0 -- Etkileşime girme mesafesi
Config.InteractKey = 38 -- E Tuşu (INPUT_CONTEXT)

Config.TravelDuration = 3500 -- Milisaniye cinsinden asansör seyahat süresi (ekranın kapalı kalacağı süre - UseCutscene false ise etkindir)

Config.UseCutscene = true -- Canlı 3D Asansör Kabini Ara Sahnesi kullanılsın mı?
Config.FloorTransitionSpeed = 1500 -- Milisaniye cinsinden kat basina gecis suresi (orn. 1500ms = her 1.5 saniyede bir kat degisir)



Config.Locales = {
    ["tr"] = {
        prompt = "[E] - Asansörü Kullan",
        target_label = "Asansörü Çağır",
        title_default = "Asansör Kontrolü",
        arrived = "Hedef kata ulaştınız.",
        moving = "ASANSÖR HAREKET EDİYOR...",
        door_open = "KAPILAR AÇILIYOR...",
        door_close = "KAPILAR KAPANIYOR...",
        alarm_triggered = "ALARM ÇALIYOR!",
        emergency_stop = "ACİL DURUM DURDURMA!",
    },
    ["en"] = {
        prompt = "[E] - Use Elevator",
        target_label = "Call Elevator",
        title_default = "Elevator Control",
        arrived = "You have arrived at your destination.",
        moving = "ELEVATOR MOVING...",
        door_open = "DOORS OPENING...",
        door_close = "DOORS CLOSING...",
        alarm_triggered = "ALARM TRIGGERED!",
        emergency_stop = "EMERGENCY STOP!",
    }
}

-- Asansör listesi ve kat koordinatları
-- coords: Oyuncunun ışınlanacağı koordinat ve bakacağı açı (x, y, z, heading)
Config.Elevators = {
    ["pillbox_hospital"] = {
        title = "Pillbox Hastanesi Asansörü",
        floors = {
            { id = "-1", label = "-1", name = "Zemin Altı Garajı", coords = vector4(344.2, -586.1, 28.8, 340.0) },
            { id = "L",  label = "L",  name = "Hastane Giriş Lobisi", coords = vector4(342.3, -588.6, 43.1, 340.0) },
            { id = "1",  label = "1",  name = "Kat 1 - Ameliyathane", coords = vector4(338.5, -583.8, 74.1, 340.0) },
            { id = "2",  label = "2",  name = "Kat 2 - Helikopter Pisti", coords = vector4(339.1, -584.2, 74.1, 340.0) } -- Helikopter pistine yakın zemin
        }
    },
    ["maze_bank"] = {
        title = "Maze Bank Kulesi Asansörü",
        floors = {
            { id = "L",  label = "L",  name = "Maze Bank Lobi", coords = vector4(-75.2, -812.5, 45.4, 325.0) },
            { id = "40", label = "40", name = "Kat 40 - Ofis Katı", coords = vector4(-75.2, -825.1, 243.3, 325.0) },
            { id = "R",  label = "R",  name = "Çatı Helikopter Pisti", coords = vector4(-75.2, -818.9, 326.1, 325.0) }
        }
    }
}
