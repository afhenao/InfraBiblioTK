// Despliegue de BiblioTK en el servidor: trabajo "bibliotk" del Jenkins de jenkins/.
// Revisa los 13 repositorios cada 5 minutos y, si alguno cambió, actualiza las copias del servidor
// (BIBLIOTK_DIR), reconstruye las imágenes (Docker reutiliza lo que no cambió) y levanta Compose.
// El .env del servidor (dominio y contraseñas) no se toca: vive solo allá

def repos = [
  [carpeta: "RegistroBiblioTK",          url: "https://github.com/Maikiuwu/RegistroBiblioTK.git"],
  [carpeta: "InicioSesionBiblioTK",      url: "https://github.com/Maikiuwu/InicioSesionBiblioTK.git"],
  [carpeta: "PerfilBiblioTK",            url: "https://github.com/Maikiuwu/PerfilBiblioTK.git"],
  [carpeta: "MaterialesBiblioTK",        url: "https://github.com/afhenao/MaterialesBiblioTK.git"],
  [carpeta: "BackDashboardBiblioTK",     url: "https://github.com/afhenao/BackDashboardBiblioTK.git"],
  [carpeta: "PrestamosBiblioTK",         url: "https://github.com/afhenao/PrestamosBiblioTK.git"],
  [carpeta: "NotificacionesBiblioTK",    url: "https://github.com/afhenao/NotificacionesBiblioTK.git"],
  [carpeta: "BiblioTK-front",            url: "https://github.com/Maikiuwu/BiblioTK-front.git"],
  [carpeta: "BiblioTK-front-user",       url: "https://github.com/Maikiuwu/BiblioTK-front-user.git"],
  [carpeta: "BiblioTK-front-admin",      url: "https://github.com/Maikiuwu/BiblioTK-front-admin.git"],
  [carpeta: "BiblioTK-front-superadmin", url: "https://github.com/Maikiuwu/BiblioTK-front-superadmin.git"],
  [carpeta: "BiblioTK-notificaciones",   url: "https://github.com/afhenao/BiblioTK-notificaciones.git"],
]

// Los que se construyen (el resto son imágenes publicadas: mariadb, redis, nginx del gateway)
def servicios = ["registro", "login", "perfil", "materiales", "dashboard", "prestamos", "notificaciones",
                 "front", "front-user", "front-admin", "front-superadmin", "movil"]

pipeline {
  agent any

  triggers {
    pollSCM("H/5 * * * *")
  }

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: "20"))
    timestamps()
    timeout(time: 90, unit: "MINUTES")
  }

  parameters {
    booleanParam(name: "SIN_CACHE", defaultValue: false,
      description: "Reconstruir las imágenes desde cero, sin la caché de Docker (más lento)")
  }

  environment {
    INFRA = "${env.BIBLIOTK_DIR}/InfraBiblioTK"
    COMPOSE = "docker compose -f docker-compose.yml -f docker-compose.servidor.yml"
  }

  stages {
    // Con el paso git, Jenkins recuerda cada repositorio y pollSCM los revisa todos
    stage("Actualizar repositorios") {
      steps {
        script {
          dir(env.INFRA) {
            git url: "https://github.com/afhenao/InfraBiblioTK.git", branch: "master"
          }
          repos.each { repo ->
            dir("${env.BIBLIOTK_DIR}/${repo.carpeta}") {
              git url: repo.url, branch: "docker-kubernetes"
            }
          }
        }
      }
    }

    // De a una imagen: con 4 GB de RAM, compilar las cinco apps de Vite a la vez no cabe
    stage("Construir imágenes") {
      steps {
        dir(env.INFRA) {
          script {
            def opciones = params.SIN_CACHE ? "--no-cache" : ""
            servicios.each { servicio ->
              sh "${env.COMPOSE} build ${opciones} ${servicio}"
            }
          }
        }
      }
    }

    stage("Desplegar") {
      steps {
        dir(env.INFRA) {
          sh "${env.COMPOSE} up -d --remove-orphans"
        }
      }
    }

    // Desde el gateway: la landing, una API por servicio y que ningún contenedor haya quedado caído
    stage("Comprobar") {
      steps {
        dir(env.INFRA) {
          sh '''
            for intento in $(seq 1 30); do
              if $COMPOSE exec -T gateway sh -c '
                for ruta in / /BiblioTK/healthLogin /MaterialesBiblioTK/Materiales /NotificacionesBiblioTK/health; do
                  wget -q -O /dev/null "http://127.0.0.1:8080$ruta" || exit 1
                done'; then
                echo "BiblioTK responde"
                break
              fi
              [ "$intento" = 30 ] && { echo "BiblioTK no responde tras el despliegue"; exit 1; }
              sleep 5
            done
            caidos=$($COMPOSE ps --status exited --status restarting --services)
            if [ -n "$caidos" ]; then echo "Contenedores caídos: $caidos"; exit 1; fi
          '''
        }
      }
    }

    // Las imágenes viejas que quedan sin etiqueta tras reconstruir (el disco es chico)
    stage("Limpiar") {
      steps {
        sh "docker image prune -f"
        sh "docker builder prune -f --filter until=168h"
      }
    }
  }

  post {
    failure {
      echo "El despliegue falló: revisar la etapa en rojo. Lo que ya estaba corriendo sigue arriba salvo que fallara en Desplegar."
    }
  }
}
