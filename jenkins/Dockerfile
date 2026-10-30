# Jenkins para desplegar BiblioTK en el servidor: el Jenkins oficial más el cliente de Docker y el
# plugin compose (hablan con el Docker del servidor por el socket montado; no hay Docker adentro)
FROM docker:29-cli AS docker

FROM jenkins/jenkins:lts-jdk21

COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
COPY --from=docker /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# Plugins que necesita el pipeline (el asistente de instalación igual ofrece los sugeridos)
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Crea el trabajo "bibliotk" la primera vez que arranca (ver semilla.groovy)
COPY semilla.groovy /usr/share/jenkins/ref/init.groovy.d/semilla.groovy
