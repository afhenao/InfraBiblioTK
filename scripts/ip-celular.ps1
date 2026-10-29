# Pone en el QR "Notificaciones" la dirección con la que el celular llega al computador, para Docker
# Compose (http://<IP>:8080/movil/) y para Kubernetes (http://<IP>/movil/).
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1             # una vez
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Vigilar    # sigue el cambio de red
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Url https://xxxx.trycloudflare.com
#   powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Instalar   # -Vigilar al iniciar sesión
# -Url: el celular está en otra red y entra por un túnel público hacia el gateway (sin /movil/)
param(
  [string]$Interfaz,
  [string]$Url,
  [switch]$Vigilar,
  [int]$Segundos = 10,
  [switch]$Instalar,
  [switch]$Desinstalar
)

$ErrorActionPreference = "Stop"
$carpeta = Split-Path -Parent $PSScriptRoot
$tarea = "BiblioTK - QR del celular"

# Tarea programada del usuario (sin administrador): corre -Vigilar oculto cada vez que inicia sesión
if ($Desinstalar) {
  Unregister-ScheduledTask -TaskName $tarea -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "Tarea '$tarea' quitada"
  return
}
if ($Instalar) {
  $argumentos = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Vigilar"
  if ($Interfaz) { $argumentos += " -Interfaz `"$Interfaz`"" }
  $accion = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentos
  $inicio = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
  $ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
  Register-ScheduledTask -TaskName $tarea -Action $accion -Trigger $inicio -Settings $ajustes -Force | Out-Null
  Start-ScheduledTask -TaskName $tarea
  Write-Host "Tarea '$tarea' instalada y en marcha: el QR seguirá la red sola"
  return
}

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
  # Docker Compose: movil/url.txt, montado en el contenedor; notificaciones lo lee en cada petición
  Set-Content -Path (Join-Path $carpeta "movil\url.txt") -Value $compose -Encoding ascii
  Write-Host "Compose: QR -> $compose"

  # Kubernetes: variable del deployment de notificaciones (si está desplegado). En Windows PowerShell,
  # con "Stop", lo que kubectl escribe en stderr (namespace inexistente) cortaría el script
  if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { return }
  $ErrorActionPreference = "Continue"
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
    try {
      Set-UrlMovil "http://${ip}:8080/movil/" "http://${ip}/movil/"
      $ultima = $ip
      Write-Host "Vuelve a cargar la landing para ver el QR nuevo."
    } catch {
      # Vigilando, un fallo puntual (archivo ocupado por OneDrive, kubectl) se reintenta en la próxima vuelta
      if (-not $Vigilar) { throw }
      Write-Warning "No pude actualizar el QR: $($_.Exception.Message)"
    }
  }

  if ($Vigilar) { Start-Sleep -Seconds $Segundos }
} while ($Vigilar)
