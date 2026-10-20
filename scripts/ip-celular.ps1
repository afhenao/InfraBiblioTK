# Pone en el QR "Notificaciones" la IP actual del computador en el Wi-Fi, para Docker Compose
# (http://<IP>:8080/movil/) y para Kubernetes (http://<IP>/movil/). Ejecutarlo cada vez que
# cambie la red:   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1
param([string]$Interfaz = "Wi-Fi")

$ErrorActionPreference = "Stop"
$carpeta = Split-Path -Parent $PSScriptRoot

$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $Interfaz -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
if (-not $ip) { throw "No encontré una IP en la interfaz '$Interfaz'. ¿Estás conectado al Wi-Fi?" }
Write-Host "IP del computador en '$Interfaz': $ip"

# Docker Compose: movil.env (lo lee el servicio notificaciones)
Set-Content -Path (Join-Path $carpeta "movil.env") -Value "MOVIL_URL=http://${ip}:8080/movil/" -Encoding ascii
$enMarcha = docker compose --project-directory $carpeta ps --services --filter status=running 2>$null
if ($enMarcha -contains "notificaciones") {
  docker compose --project-directory $carpeta up -d notificaciones | Out-Null
  Write-Host "Compose: QR -> http://${ip}:8080/movil/"
} else {
  Write-Host "Compose no está corriendo: el QR tomará http://${ip}:8080/movil/ al levantarlo"
}

# Kubernetes: variable del deployment de notificaciones (si está desplegado)
kubectl get namespace bibliotk *> $null
if ($LASTEXITCODE -eq 0) {
  kubectl -n bibliotk set env deployment/notificaciones "MOVIL_URL=http://${ip}/movil/" | Out-Null
  kubectl -n bibliotk rollout status deployment/notificaciones --timeout=120s | Out-Null
  Write-Host "Kubernetes: QR -> http://${ip}/movil/"
}
