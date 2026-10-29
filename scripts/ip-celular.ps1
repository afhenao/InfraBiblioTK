# Pone en el QR "Notificaciones" la dirección con la que el celular llega al computador, para Docker
# Compose (http://<IP>:8080/movil/) y para Kubernetes (http://<IP>/movil/).
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1             # una vez
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Vigilar    # sigue el cambio de red
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Url https://xxxx.trycloudflare.com
# -Url: el celular está en otra red y entra por un túnel público hacia el gateway (sin /movil/)
param(
  [string]$Interfaz,
  [string]$Url,
  [switch]$Vigilar,
  [int]$Segundos = 10
)

$ErrorActionPreference = "Stop"
$carpeta = Split-Path -Parent $PSScriptRoot

# Mismo criterio que NotificacionesBiblioTK/src/utils/movil.js: sin adaptadores virtuales ni la red
# solo-anfitrión de VirtualBox (192.168.56.x), y el Wi-Fi primero
$adaptadoresVirtuales = "vEthernet|VirtualBox|VMware|Hyper-V|WSL|Docker|vboxnet|Loopback"

function Get-IpEnLaRed {
  $activos = (Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq "Up").Name
  $candidatas = Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred -ErrorAction SilentlyContinue |
    Where-Object {
      $_.InterfaceAlias -in $activos -and
      $_.InterfaceAlias -notmatch $adaptadoresVirtuales -and
      $_.IPAddress -notlike "169.254.*" -and
      $_.IPAddress -notlike "192.168.56.*"
    }

  if ($Interfaz) { $candidatas = $candidatas | Where-Object InterfaceAlias -eq $Interfaz }

  $wifi = $candidatas | Where-Object InterfaceAlias -match "wi-?fi|wlan|wireless|inal" | Select-Object -First 1
  if (-not $wifi) { $wifi = $candidatas | Select-Object -First 1 }
  return $wifi.IPAddress
}

function Set-UrlMovil([string]$compose, [string]$kubernetes) {
  # Docker Compose: movil.env (lo lee el servicio notificaciones; hay que recrearlo para que lo tome)
  Set-Content -Path (Join-Path $carpeta "movil.env") -Value "MOVIL_URL=$compose" -Encoding ascii
  $enMarcha = docker compose --project-directory $carpeta ps --services --filter status=running 2>$null
  if ($enMarcha -contains "notificaciones") {
    docker compose --project-directory $carpeta up -d notificaciones 2>$null | Out-Null
    Write-Host "Compose: QR -> $compose"
  } else {
    Write-Host "Compose no está corriendo: el QR tomará $compose al levantarlo"
  }

  # Kubernetes: variable del deployment de notificaciones (si está desplegado)
  kubectl get namespace bibliotk *> $null
  if ($LASTEXITCODE -eq 0) {
    kubectl -n bibliotk set env deployment/notificaciones "MOVIL_URL=$kubernetes" | Out-Null
    kubectl -n bibliotk rollout status deployment/notificaciones --timeout=120s | Out-Null
    Write-Host "Kubernetes: QR -> $kubernetes"
  }
}

if ($Url) {
  $base = $Url.TrimEnd("/")
  Set-UrlMovil "$base/movil/" "$base/movil/"
  return
}

$ultima = $null
do {
  $ip = Get-IpEnLaRed

  if (-not $ip) {
    if (-not $Vigilar) { throw "No encontré una IP en la red local. ¿Estás conectado al Wi-Fi o al cable?" }
    if ($ultima -ne "") { Write-Host "Sin red por ahora: espero a que vuelva la conexión..." }
    $ultima = ""
  } elseif ($ip -ne $ultima) {
    Write-Host "IP del computador en la red local: $ip"
    Set-UrlMovil "http://${ip}:8080/movil/" "http://${ip}/movil/"
    $ultima = $ip
    Write-Host "Vuelve a cargar la landing para ver el QR nuevo."
  }

  if ($Vigilar) { Start-Sleep -Seconds $Segundos }
} while ($Vigilar)
