# Jenkins controller for the Dockerized ACM workshop.
# Bundles: docker CLI + compose plugin (talks to the mounted host socket),
# maven (for the "Build Code" stage), jq/curl, and all required plugins
# incl. the Dynatrace SaaS/Managed performance-signature plugin.
FROM jenkins/jenkins:lts-jdk17

USER root

# --- docker CLI + compose plugin, maven, helpers ----------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg maven jq \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
 && . /etc/os-release \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
 && rm -rf /var/lib/apt/lists/*

USER jenkins

# --- plugins ----------------------------------------------------------------
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt --latest true

# skip the setup wizard; JCasC + Job DSL bootstrap everything
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/dtacm/jenkins/casc
