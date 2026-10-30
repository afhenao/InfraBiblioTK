# InfraBiblioTK — Docker Compose, gateway y Kubernetes

Parte del sistema BiblioTK (ver `../CLAUDE.md`). Todo lo necesario para levantar el sistema completo en contenedores: con **Docker Compose** (`http://localhost:8080`) o con **Kubernetes de Docker Desktop** (`http://localhost`). Cada servicio y cada app tiene su propio `Dockerfile` en su repositorio; aquí están la orquestación, el gateway y la base de datos inicial.

## Arquitectura

```
navegador / celular ──▶ gateway (nginx, único origen) ──┬─ /                 → front            (landing)
                                                         ├─ /lector/          → front-user
                                                         ├─ /bibliotecario/   → front-admin
                                                         ├─ /superadmin/      → front-superadmin
                                                         ├─ /movil/           → movil            (app del celular)
                                                         ├─ /RegistroBiblioTK → registro:3000
                                                         ├─ /BiblioTK         → login:3001
                                                         ├─ /PerfilBiblioTK   → perfil:3002
                                                         ├─ /MaterialesBiblioTK → materiales:3003 (+ volumen de portadas)
                                                         ├─ /DashboardBibliotk → dashboard:3004
                                                         ├─ /PrestamosBiblioTK → prestamos:3005
                                                         └─ /NotificacionesBiblioTK → notificaciones:3006 (WebSocket; /interno → 404)
servicios ──▶ mariadb:3306 (volumen)    notificaciones ──▶ redis:6379
```

- **Un solo origen:** una sola cookie de sesión, sin CORS entre apps y cada servicio con su prefijo de siempre. Por eso las apps se compilan con rutas relativas (`VITE_*` vacías o con `/Prefijo/...`) y una subruta (`VITE_BASE`); el gateway quita la subruta antes de pasar a cada nginx.
- `gateway/nginx.conf.template` sirve **igual** para Compose y Kubernetes: los nombres (`login`, `front-user`…) son servicios en los dos. Es una plantilla: la imagen de nginx pone el DNS del contenedor (`NGINX_LOCAL_RESOLVERS`: Docker o kube-dns) y el sufijo `DOMINIO` (vacío en Compose, `.bibliotk.svc.cluster.local` en Kubernetes). Los nombres se resuelven en cada petición (cacheados 10 s): antes se resolvían solo al arrancar y, al recrear un contenedor, el gateway seguía mandando a la IP vieja, que podía ser de otra app.
- `/NotificacionesBiblioTK/interno/` no se publica (solo los backends avisan eventos, dentro de la red) y además exige `NOTIFICACIONES_CLAVE`.
- `/gateway-salud`: salud del propio gateway.

## Archivos

| Archivo | Para qué |
|---|---|
| `docker-compose.yml` | Los 15 servicios (MariaDB, Redis, 7 backends, 5 apps y el gateway). Construye las imágenes `bibliotk/<servicio>:local` desde las carpetas vecinas |
| `.env.example` | Contraseñas y `NOTIFICACIONES_CLAVE` para Compose (copiar como `.env`, que no se sube) |
| `docker-compose.servidor.yml` | Se suma al anterior en el servidor: sin puertos de Redis ni MariaDB y el gateway solo en `127.0.0.1:8080` (para el túnel) |
| `scripts/servidor.sh` | En la VM: clona o actualiza los 12 repositorios junto a `InfraBiblioTK` y levanta Compose para el servidor |
| `scripts/ip-celular.ps1` | Pone la IP actual de la red en el QR del celular (`movil/url.txt` en Compose, `set env` en Kubernetes) |
| `gateway/nginx.conf.template` | Reparto por prefijo, WebSocket, bloqueo de `/interno` y DNS en cada petición |
| `mariadb/initdb/` | `01-esquema.sql` (usuarios, materiales, préstamos, idénticas a la BD local) y `02-materiales.sql` (8 libros de ejemplo). Solo corren con el volumen vacío |
| `kustomization.yaml` | Kubernetes: junta `k8s/*.yaml` y genera los ConfigMap (configuración, nginx, SQL inicial) y el Secret |
| `k8s/` | `namespace`, `mariadb` (StatefulSet + volumen), `redis`, `backends` (6 servicios + volumen de portadas), `notificaciones` (**2 réplicas**), `apps` (5 nginx) y `gateway` (LoadBalancer en el puerto 80) |
| `k8s/config.env` | Configuración común sin secretos (orígenes, URLs de las apps, `MOVIL_URL` de base) |
| `k8s/secretos.env.example` | Copiar como `k8s/secretos.env` (no se sube) |

## Docker Compose

```bash
cd InfraBiblioTK
docker compose up -d --build        # todo: http://localhost:8080
docker compose ps                   # estado (MariaDB y Redis con healthcheck)
docker compose logs -f notificaciones
docker compose down                 # parar (conserva la BD); down -v la borra
docker compose up -d redis          # solo Redis, para desarrollar con npm run dev
```

- La BD del contenedor es **otra** (volumen `bd`), no la MariaDB local: arranca con el esquema y los 8 libros, sin cuentas. Para verla en HeidiSQL: `127.0.0.1`, puerto **3307**, base `bibliotk`, usuario y contraseña **de cuando se creó el volumen**: `DB_USER`/`DB_PASSWORD` (o `root` / `DB_ROOT_PASSWORD`) de `InfraBiblioTK/.env`; sin `.env`, `bibliotk` / `bibliotk-local` o `root` / `bibliotk-root-local`. No es la contraseña de la MariaDB local. Solo se publica en el propio computador.
- Usar `http://localhost:8080` en el computador (no `127.0.0.1`): la cookie y las URLs de destino son de `localhost`.

## Servidor (VM Ubuntu + túnel de Cloudflare)

El mismo Compose, con el dominio en `URL_PUBLICA` y `docker-compose.servidor.yml` encima. El túnel (`cloudflared` en la VM) es lo único que entra: apunta a `http://localhost:8080` y Cloudflare pone el HTTPS (WebSocket incluido).

1. En la VM: Docker Engine con el plugin compose y `git` con acceso a los repositorios.
2. Clonar `InfraBiblioTK` y crear `InfraBiblioTK/.env` (no se sube; contraseñas con `openssl rand -hex 24`; las de MariaDB solo se fijan con el volumen vacío):
   ```
   URL_PUBLICA=https://<dominio>          # con https y sin / al final
   COOKIE_SECURE=true                     # la cookie de sesión solo viaja por HTTPS
   DB_USER=bibliotk
   DB_PASSWORD=<aleatoria>
   DB_ROOT_PASSWORD=<aleatoria>
   NOTIFICACIONES_CLAVE=<aleatoria>
   SUPERADMIN_EMAIL=<correo>              # superadmin inicial (opcional, ver abajo)
   SUPERADMIN_CONTRASENA=<la tuya, 8+>
   ```
3. `bash InfraBiblioTK/scripts/servidor.sh`: clona o actualiza los demás repositorios (rama `docker-kubernetes`) en la carpeta de al lado y hace `docker compose -f docker-compose.yml -f docker-compose.servidor.yml up -d --build`. Para actualizar después, el mismo comando.
4. En el túnel: hostname público `<dominio>` → servicio `http://localhost:8080`.

- `URL_PUBLICA` llena `ALLOWED_ORIGIN_1`, `APP_*_URL` de InicioSesion y `MOVIL_URL` (el QR muestra `https://<dominio>/movil/`, que sirve desde cualquier red). Sin ella, todo queda en `http://localhost:8080`, como en el computador.
- **Superadmin:** el registro solo crea lectores. Con `SUPERADMIN_EMAIL` y `SUPERADMIN_CONTRASENA` en `.env` (opcional `SUPERADMIN_USUARIO`, por defecto `superadmin`), login crea esa cuenta al arrancar **si no hay ningún superadmin**; si ya hay uno, no toca nada, y si el correo ya está registrado no lo promueve (cualquiera podría registrarse antes con ese correo). Tras editar `.env`: `docker compose -f docker-compose.yml -f docker-compose.servidor.yml up -d login`. La contraseña la elige quien administra el servidor: nunca va en el repositorio. Alternativa a mano: `bash scripts/crear-superadmin.sh` (pide los datos). Desde la app de superadmin se cambia el rol de las demás cuentas (bibliotecarios).

## Kubernetes (Docker Desktop)

Requisitos: Kubernetes activado en Docker Desktop (este equipo usa el modo **kind**, nodo `desktop-control-plane`) y las imágenes construidas con `docker compose build`. El nodo las toma del motor de Docker a través del *registry mirror* de Docker Desktop, por eso los manifiestos usan `imagePullPolicy: Always`: con `Never` fallan (la imagen no está "dentro" del nodo hasta que se pide) y con `IfNotPresent` el nodo se queda con la versión vieja de la etiqueta `:local` aunque se reconstruya. Con `Always` basta `kubectl rollout restart` para tomar la nueva (el mirror es local, así que es rápido).

```bash
cd InfraBiblioTK
docker compose build                              # imágenes bibliotk/*:local
cp k8s/secretos.env.example k8s/secretos.env      # y poner contraseñas propias
kubectl apply -k .                                # todo en el namespace bibliotk
kubectl -n bibliotk get pods                      # 16 pods (notificaciones x2)
kubectl -n bibliotk rollout restart deployment/login   # tras reconstruir una imagen
kubectl delete -k .                               # quitarlo (el volumen de MariaDB queda: kubectl -n bibliotk delete pvc --all)
```

- El gateway es `type: LoadBalancer`: Docker Desktop lo publica en `0.0.0.0:80` → `http://localhost` (y `http://<IP del computador>` desde el celular).
- Los backends esperan a MariaDB (y notificaciones a Redis) con un `initContainer` (`nc -z`), y tienen sondas `readiness`/`liveness` en sus rutas `/health`.
- Contenedores sin root (`node` uid 1000, nginx uid 101), sin escalada de privilegios y sin capacidades.
- **Varias réplicas de notificaciones:** los clientes usan solo WebSocket (sin afinidad de sesión) y el adaptador de Redis reparte cada evento: un aviso publicado en un pod llega a los sockets de todos.

## El QR del celular (`MOVIL_URL`)

Dentro de un contenedor no se ve la IP del computador, así que hay que darla. `scripts/ip-celular.ps1` busca sola la IP actual en la red local (el Wi-Fi primero; se salta adaptadores virtuales y la red 192.168.56.x de VirtualBox, mismo criterio que `NotificacionesBiblioTK/src/utils/movil.js`) y la pone donde haga falta:

```powershell
powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1            # una vez (o -Interfaz Ethernet)
powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Vigilar   # se queda corriendo
powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Url https://xxxx.trycloudflare.com
powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1 -Instalar   # o -Desinstalar
```

- **Compose:** escribe `http://<IP>:8080/movil/` en `movil/url.txt` (no se sube). La carpeta `movil/` está montada en `notificaciones` (`MOVIL_URL_ARCHIVO=/movil/url.txt`) y el servicio lee el archivo **en cada petición**: el QR cambia sin reiniciar nada (`movil.env` ya no se usa).
- **Kubernetes:** si existe el namespace `bibliotk`, hace `kubectl -n bibliotk set env deployment/notificaciones MOVIL_URL=http://<IP>/movil/` (eso reinicia el pod; `k8s/config.env` trae `http://localhost/movil/` de base y un `kubectl apply -k .` lo devuelve a ese valor).
- **Cambio de red:** con `-Vigilar` revisa la IP cada 10 s (`-Segundos`) y actualiza el QR apenas cambia; basta volver a cargar la landing. `-Instalar` crea una tarea programada del usuario ("BiblioTK - QR del celular", sin administrador) que lo deja vigilando, oculto, cada vez que inicia sesión; `-Desinstalar` la quita. Sin vigilante, hay que correr el script en cada red.
- **Celular en otra red** (datos móviles, o una red con aislamiento de clientes, típica de universidad u oficina): la IP local no le sirve. Hay que publicar el gateway con un túnel (p. ej. `cloudflared tunnel --url http://localhost:8080`) y pasar esa dirección con `-Url` (sin `/movil/`, el script lo agrega). El socket de la app del celular va por el mismo origen, así que el túnel basta. Otra opción: conectar el computador al punto de acceso del celular y correr el script.

## Probar las apps del bibliotecario o del superadministrador

El registro solo crea lectores. Para cambiar el rol de una cuenta en la BD del contenedor:

```bash
# Compose (usuario/contraseña de MariaDB: los de InfraBiblioTK/.env o los de ejemplo)
docker compose exec mariadb mariadb -u bibliotk -p bibliotk -e "UPDATE usuarios SET rol = 'admin' WHERE email = 'correo@ejemplo.com';"
# Kubernetes
kubectl -n bibliotk exec -it mariadb-0 -- mariadb -u bibliotk -p bibliotk -e "UPDATE usuarios SET rol = 'superadmin' WHERE email = 'correo@ejemplo.com';"
```

## Problemas conocidos

- **Las contraseñas de MariaDB se fijan la primera vez** (volumen vacío). Si después cambian en `.env` o `k8s/secretos.env`, los servicios reciben "Access denied": hay que cambiarlas también dentro de MariaDB (`ALTER USER … IDENTIFIED BY …` como root, con la contraseña vieja) o borrar el volumen.
- Las variables `VITE_*` quedan fijas al compilar cada app: para servir en otro dominio o puerto hay que reconstruir las imágenes de las apps (y cambiar `ALLOWED_ORIGIN_1` y `APP_*_URL`).
- Sin `.env`/`secretos.env` propios, Compose usa contraseñas de ejemplo: aceptables solo en el propio computador (la BD no se publica fuera de la red de Compose).
- Docker Desktop de este equipo se cae al arrancar si quedan sockets viejos en `%LOCALAPPDATA%\Docker\run` o `%LOCALAPPDATA%\docker-secrets-engine` ("The file cannot be accessed by the system"): cerrar Docker Desktop, renombrar esa carpeta y volver a abrirlo (Windows no deja borrar esos sockets hasta reiniciar).
