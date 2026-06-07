// ==========================================
// SES SENTEZLEYİCİ - WEB AUDIO API
// (Ekstra ses dosyası indirmeden çalışan yerel motor)
// ==========================================
class ElevatorAudioEngine {
    constructor() {
        this.ctx = null;
        this.motorOsc = null;
        this.motorGain = null;
        this.alarmOsc = null;
        this.alarmInterval = null;
    }

    init() {
        if (!this.ctx) {
            this.ctx = new (window.AudioContext || window.webkitAudioContext)();
        }
    }

    // Buton Tıklama Sesi (Mekanik "Tık" efekti)
    playClick() {
        this.init();
        const now = this.ctx.currentTime;
        
        // Çok kısa bir yüksek frekanslı tık sesi
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(1000, now);
        osc.frequency.exponentialRampToValueAtTime(150, now + 0.04);
        
        gain.gain.setValueAtTime(0.15, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.04);
        
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        
        osc.start(now);
        osc.stop(now + 0.05);
    }

    // Asansör Varış Çan Sesi (Efsanevi Çift Tonlu "DİNG!" Efekti)
    playChime() {
        this.init();
        const now = this.ctx.currentTime;
        
        // Asansör çanları genelde iki harmonik tonun birleşimidir
        // Ana frekanslar: 880Hz (A5) ve 554.37Hz (C#5) - Çok temiz ve lüks bir ton
        const freqs = [880, 554.37];
        
        freqs.forEach((freq, idx) => {
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now);
            
            // Lüks asansörlerde zil yavaşça söner (exponential decay)
            gain.gain.setValueAtTime(idx === 0 ? 0.25 : 0.15, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 2.0);
            
            osc.connect(gain);
            gain.connect(this.ctx.destination);
            
            osc.start(now);
            osc.stop(now + 2.1);
        });
    }

    // Asansör Hareket Uğultusu (Alçak Frekanslı Motor Sesi)
    startMotorHum() {
        this.init();
        if (this.motorOsc) return;

        const now = this.ctx.currentTime;
        
        // Düşük motor uğultusu için sawtooth + lowpass filtre
        this.motorOsc = this.ctx.createOscillator();
        this.motorGain = this.ctx.createGain();
        const filter = this.ctx.createBiquadFilter();
        
        this.motorOsc.type = 'sawtooth';
        this.motorOsc.frequency.setValueAtTime(45, now); // 45 Hz derin motor sesi
        
        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(90, now); // Sadece alçak frekansları geçir
        
        this.motorGain.gain.setValueAtTime(0.001, now);
        // Yumuşak kalkış (Fade in)
        this.motorGain.gain.linearRampToValueAtTime(0.18, now + 1.0);
        
        this.motorOsc.connect(filter);
        filter.connect(this.motorGain);
        this.motorGain.connect(this.ctx.destination);
        
        this.motorOsc.start(now);
    }

    stopMotorHum() {
        if (!this.motorOsc) return;
        
        const now = this.ctx.currentTime;
        // Yumuşak duruş (Fade out)
        this.motorGain.gain.setValueAtTime(this.motorGain.gain.value, now);
        this.motorGain.gain.exponentialRampToValueAtTime(0.001, now + 0.8);
        
        const osc = this.motorOsc;
        setTimeout(() => {
            try { osc.stop(); } catch(e) {}
        }, 900);
        
        this.motorOsc = null;
        this.motorGain = null;
    }

    // Acil Durum Alarm Sesi (Aralıklı Yüksek Biip)
    toggleAlarm(active) {
        this.init();
        
        if (!active) {
            if (this.alarmInterval) {
                clearInterval(this.alarmInterval);
                this.alarmInterval = null;
            }
            return;
        }

        if (this.alarmInterval) return;

        const playAlarmBeep = () => {
            const now = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();

            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, now);

            gain.gain.setValueAtTime(0.15, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

            osc.connect(gain);
            gain.connect(this.ctx.destination);

            osc.start(now);
            osc.stop(now + 0.4);
        };

        playAlarmBeep();
        this.alarmInterval = setInterval(playAlarmBeep, 800);
    }

    // Acil Durum Durdurma Hatası (Kısa Hata Sesi)
    playEmergencyBeep() {
        this.init();
        const now = this.ctx.currentTime;
        
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(130, now);
        
        gain.gain.setValueAtTime(0.2, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.35);
        
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        
        osc.start(now);
        osc.stop(now + 0.4);
    }
}

// Ses Sınıfını Başlat
const audio = new ElevatorAudioEngine();

// ==========================================
// ARAYÜZ YÖNETİMİ & EVENT LISTENERLARI
// ==========================================
const container = document.getElementById("elevator-container");
const panel = document.getElementById("elevator-panel");
const displayFloor = document.getElementById("display-floor");
const ledLight = document.getElementById("led-light");
const floorsContainer = document.getElementById("floors-container");
const panelTitle = document.getElementById("panel-title");

let currentElevator = null;
let currentFloorVal = null;
let isTraveling = false;
let isAlarming = false;
let isStopped = false;

// NUI Dinleyici
window.addEventListener("message", function(event) {
    const data = event.data;
    
    if (data.action === "open") {
        setupElevator(data.elevator, data.title, data.floors, data.currentFloor);
    } else if (data.action === "close") {
        closeElevator();
    } else if (data.action === "start_travel") {
        startTravelAnimation(data.floorId);
    } else if (data.action === "arrived") {
        arriveAtFloor(data.floorId);
    }
});

// ESC Tuşuna basıldığında kapat
document.addEventListener("keydown", function(event) {
    if (event.key === "Escape" || event.key === "Esc") {
        if (!isTraveling) {
            axios_close();
        }
    }
});

// Boş alana çift tıklandığında da kapat (Kullanıcı kolaylığı)
document.getElementById("backdrop").addEventListener("dblclick", function() {
    if (!isTraveling) {
        axios_close();
    }
});

// Asansör Arayüzünü Kur
function setupElevator(elevator, title, floors, currentFloor) {
    currentElevator = elevator;
    currentFloorVal = currentFloor;
    isTraveling = false;
    isAlarming = false;
    isStopped = false;

    // Başlığı ayarla
    panelTitle.textContent = title.toUpperCase();

    // LED Göstergesini sıfırla
    ledLight.className = "led-indicator";
    
    // Aktif kat ismini bulup ekrana yaz
    const activeFloorObj = floors.find(f => f.id === currentFloor);
    displayFloor.textContent = activeFloorObj ? activeFloorObj.name.toUpperCase() : "READY";

    // Kat Düğmelerini Dinamik Oluştur
    floorsContainer.innerHTML = "";

    // Düğmeleri gerçek asansörlerdeki gibi yüksekten alçağa (yukarıdan aşağı) sırala
    // Örneğin 12 en üstte, L en altta dursun
    const sortedFloors = [...floors].reverse();

    sortedFloors.forEach(floor => {
        const row = document.createElement("div");
        row.className = "button-row";
        
        const plaque = document.createElement("div");
        plaque.className = "floor-plaque";
        
        const plaqueText = document.createElement("span");
        plaqueText.className = "plaque-text";
        plaqueText.textContent = floor.label;
        plaque.appendChild(plaqueText);

        const button = document.createElement("button");
        button.className = "elevator-btn";
        button.dataset.id = floor.id;
        button.dataset.name = floor.name;
        button.textContent = floor.label;

        // Eğer oyuncu bu kattaysa butonu aktif et (glowing)
        if (floor.id === currentFloor) {
            button.classList.add("active");
        }

        // Tıklama olayı
        button.addEventListener("click", () => {
            if (isTraveling || isStopped) return;
            if (floor.id === currentFloorVal) {
                audio.playEmergencyBeep(); // Zaten aynı kattaysa bip çalsın
                return;
            }
            
            // Seçimi doğrula
            audio.playClick();
            selectFloor(floor.id);
        });

        row.appendChild(plaque);
        row.appendChild(button);
        floorsContainer.appendChild(row);
    });



    // Paneli göster ve slayt ile kaydır
    container.style.display = "block";
    setTimeout(() => {
        panel.style.right = "40px";
    }, 50);
}

// Kat seçildiğinde sunucuya/istemciye bildir
function selectFloor(floorId) {
    const buttons = document.querySelectorAll(".elevator-btn");
    let targetButton = null;

    buttons.forEach(btn => {
        btn.classList.remove("active");
        if (btn.dataset.id === floorId) {
            targetButton = btn;
        }
    });

    if (targetButton) {
        targetButton.classList.add("blinking");
    }

    // Lua tarafına veri gönder
    fetch(`https://${GetParentResourceName()}/select_floor`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            elevator: currentElevator,
            floorId: floorId
        })
    });
}

// Seyahat Başlangıç Animasyonu
function startTravelAnimation(floorId) {
    isTraveling = true;
    
    // LED Göstergesini sarı yanıp söner yap
    ledLight.className = "led-indicator moving";
    displayFloor.textContent = "HAREKET EDİYOR...";

    // Motor sesini başlat
    audio.startMotorHum();
}

// Hedef Kata Ulaşınca Çalışacak Animasyon
function arriveAtFloor(floorId) {
    isTraveling = false;
    currentFloorVal = floorId;

    // Düğme yanıp sönmesini kaldır ve sabit parlar yap
    const buttons = document.querySelectorAll(".elevator-btn");
    buttons.forEach(btn => {
        btn.classList.remove("blinking");
        btn.classList.remove("active");
        if (btn.dataset.id === floorId) {
            btn.classList.add("active");
            displayFloor.textContent = btn.dataset.name.toUpperCase();
        }
    });

    // Motor sesini durdur, çan sesi çal
    audio.stopMotorHum();
    audio.playChime();

    // LED yeşile dönsün
    ledLight.className = "led-indicator";
}

// Paneli Kapat ve Gizle
function closeElevator() {
    panel.style.right = "-400px";
    audio.stopMotorHum();
    audio.toggleAlarm(false);
    
    setTimeout(() => {
        container.style.display = "none";
    }, 600);
}

// Lua'ya kapatma sinyali gönder
function axios_close() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({})
    });
}


