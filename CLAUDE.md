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
| `scripts/ip-celular.ps1` | Pone la IP actual del Wi-Fi en el QR del celular (`movil.env` en Compose, `set env` en Kubernetes) |
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

Dentro de un contenedor no se ve la IP del computador, así que hay que darla. `scripts/ip-celular.ps1` toma la IP actual del Wi-Fi y la pone donde haga falta:

```powershell
powershell -ExecutionPolicy Bypass -File InfraBiblioTK\scripts\ip-celular.ps1          # o -Interfaz Ethernet
```

- **Compose:** escribe `MOVIL_URL=http://<IP>:8080/movil/` en `movil.env` (no se sube; `notificaciones` lo lee con `env_file`, opcional) y, si Compose está arriba, recrea `notificaciones`.
- **Kubernetes:** si existe el namespace `bibliotk`, hace `kubectl -n bibliotk set env deployment/notificaciones MOVIL_URL=http://<IP>/movil/` (`k8s/config.env` trae `http://localhost/movil/` de base; un `kubectl apply -k .` lo devuelve a ese valor, así que hay que volver a correr el script).
- **Hay que correrlo cada vez que cambia la red** (la IP del Wi-Fi cambia) y volver a cargar la landing para que el QR sea el nuevo.
- Si el celular dice "rechazó la conexión" o "no se puede acceder" con la IP correcta, la red no deja que los equipos se vean entre sí (pasa en redes de universidad u oficina, con aislamiento de clientes). Solución: conectar el computador al punto de acceso del celular y volver a correr el script.

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
