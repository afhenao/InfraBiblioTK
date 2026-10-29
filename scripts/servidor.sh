#!/usr/bin/env bash
# Despliegue en el servidor (VM Ubuntu detrás de un túnel de Cloudflare). Clona o actualiza los
# repositorios junto a InfraBiblioTK y levanta Compose con docker-compose.servidor.yml:
#   bash InfraBiblioTK/scripts/servidor.sh
# Requisitos: Docker Engine con el plugin compose, git con acceso a los repositorios y
# InfraBiblioTK/.env (ver "Servidor" en InfraBiblioTK/CLAUDE.md).
set -euo pipefail

infra="$(cd "$(dirname "$0")/.." && pwd)"
raiz="$(dirname "$infra")"

# carpeta  repositorio  rama
repos=(
  "RegistroBiblioTK          https://github.com/Maikiuwu/RegistroBiblioTK.git          docker-kubernetes"
  "InicioSesionBiblioTK      https://github.com/Maikiuwu/InicioSesionBiblioTK.git      docker-kubernetes"
  "PerfilBiblioTK            https://github.com/Maikiuwu/PerfilBiblioTK.git            docker-kubernetes"
  "MaterialesBiblioTK        https://github.com/afhenao/MaterialesBiblioTK.git         docker-kubernetes"
  "BackDashboardBiblioTK     https://github.com/afhenao/BackDashboardBiblioTK.git      docker-kubernetes"
  "PrestamosBiblioTK         https://github.com/afhenao/PrestamosBiblioTK.git          docker-kubernetes"
  "NotificacionesBiblioTK    https://github.com/afhenao/NotificacionesBiblioTK.git     docker-kubernetes"
  "BiblioTK-front            https://github.com/Maikiuwu/BiblioTK-front.git            docker-kubernetes"
  "BiblioTK-front-user       https://github.com/Maikiuwu/BiblioTK-front-user.git       docker-kubernetes"
  "BiblioTK-front-admin      https://github.com/Maikiuwu/BiblioTK-front-admin.git      docker-kubernetes"
  "BiblioTK-front-superadmin https://github.com/Maikiuwu/BiblioTK-front-superadmin.git docker-kubernetes"
  "BiblioTK-notificaciones   https://github.com/afhenao/BiblioTK-notificaciones.git    docker-kubernetes"
)

git -C "$infra" pull --ff-only

for linea in "${repos[@]}"; do
  read -r carpeta url rama <<<"$linea"
  if [ -d "$raiz/$carpeta/.git" ]; then
    echo "Actualizando $carpeta ($rama)"
    git -C "$raiz/$carpeta" fetch --quiet origin "$rama"
    git -C "$raiz/$carpeta" checkout --quiet "$rama"
    git -C "$raiz/$carpeta" pull --quiet --ff-only origin "$rama"
  else
    echo "Clonando $carpeta ($rama)"
    git clone --quiet --branch "$rama" "$url" "$raiz/$carpeta"
  fi
done

if [ ! -f "$infra/.env" ]; then
  echo "Falta $infra/.env (URL_PUBLICA, COOKIE_SECURE y contraseñas): ver InfraBiblioTK/CLAUDE.md" >&2
  exit 1
fi

cd "$infra"
docker compose -f docker-compose.yml -f docker-compose.servidor.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.servidor.yml ps
echo "Listo: el túnel debe apuntar a http://localhost:8080"
