# =====================================================================
# PureTogether - Simulator Pengirim Paket UDP (Hardware Mock Transmitter)
# =====================================================================
# Script ini digunakan untuk mengetes penerimaan paket UDP pada aplikasi
# Android/Flutter Anda dari laptop/PC tanpa harus menyalakan hardware asli.
#
# CARA PENGGUNAAN:
# 1. Pastikan laptop dan HP berada dalam satu jaringan Wi-Fi yang sama
#    (atau HP terhubung ke Wi-Fi laptop, atau jika pakai emulator gunakan 127.0.0.1).
# 2. Cek IP HP Anda di Wi-Fi Settings (misal: 192.168.1.50 atau 192.168.4.2).
# 3. Jalankan script ini di terminal PowerShell:
#    powershell -ExecutionPolicy Bypass -File .\scripts\test_udp_sender.ps1 -TargetIp "192.168.1.50"
# =====================================================================

param(
    [string]$TargetIp = "127.0.0.1",
    [int]$Port = 8888,
    [int]$IntervalSec = 1
)

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   PureTogether UDP Robot Simulator (Port $Port)        " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Target Pengiriman: $TargetIp : $Port" -ForegroundColor Yellow
Write-Host "Interval          : $IntervalSec detik" -ForegroundColor Yellow
Write-Host "Tekan CTRL + C untuk menghentikan simulasi.`n" -ForegroundColor Gray

$udpClient = New-Object System.Net.Sockets.UdpClient

$counter = 0
$volt = 12.1

try {
    while ($true) {
        $counter++
        
        # Simulasi debu normal vs bahaya sesekali
        if ($counter % 8 -eq 0) {
            $debu = 125.40
            $status = "Bahaya"
        } else {
            $debu = [math]::Round(14.0 + (Get-Random -Minimum 0.0 -Maximum 8.5), 2)
            $status = "Aman"
        }

        # Baterai perlahan berkurang sedikit
        $volt = [math]::Round([math]::Max(11.0, 12.2 - ($counter * 0.01)), 2)

        # JSON payload sesuai spesifikasi hardware STM32 + ESP-01
        $payload = "{`"status`":`"$status`",`"debu_value`":$debu,`"battery_voltage`":$volt,`"map_data`":`"L4500,K,L2000,Ki,L3000,K,`"}"
        
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $udpClient.Send($bytes, $bytes.Length, $TargetIp, $Port) | Out-Null

        $timeStr = [DateTime]::Now.ToString("HH:mm:ss.fff")
        if ($status -eq "Bahaya") {
            Write-Host "[$timeStr] SENT (ALERT) -> $payload" -ForegroundColor Red
        } else {
            Write-Host "[$timeStr] SENT -> $payload" -ForegroundColor Green
        }

        Start-Sleep -Seconds $IntervalSec
    }
} catch {
    Write-Host "`n[ERROR] Terjadi kesalahan: $_" -ForegroundColor Red
} finally {
    $udpClient.Close()
    Write-Host "`nSocket UDP ditutup.`n" -ForegroundColor Gray
}
