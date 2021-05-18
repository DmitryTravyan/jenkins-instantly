FROM registry.access.redhat.com/ubi8:latest

USER root:root

######################################## JENKINS ################################
# Jenkins ARGS
ARG JENKINS_NAME
ARG JENKINS_VERSION
ARG JENKINS_DOMAIN
ARG JENKINS_MASTER_PORT
ARG SLAVE_PORT
ARG USER
ARG GROUP
ARG UID
ARG GID
ARG JENKINS_HOME
ARG JENKINS_OPTS
ARG JENKINS_WAR_CENTER
ARG JENKINS_UPDATE_CENTER
ARG PLUGIN_MANAGER_VERSION
ARG PLUGIN_MANAGER_URL
ARG JAVA_OPTS
ARG JAVA_MEMORY_ARGS
ARG CERTS_ANCHORS
ARG SESSION_TIMEOUT
ARG VAULT_DOMAIN

# Jenkins ENVs
ENV JENKINS_HOME=${JENKINS_HOME} \
    CERT_ANCHORS=${CERT_ANCHORS} \
    JENKINS_VERSION=${JENKINS_VERSION} \
    HTTP_PORT=${JENKINS_MASTER_PORT} \
    AGENT_PORT=${JENKINS_AGENT_PORT} \
    JENKINS_USER=${USER} \
    JENKINS_GROUP=${GROUP} \
    UID=${UID} \
    GID=${GID} \
    HOME=${JENKINS_HOME} \
    JAVA_OPTS=${JAVA_OPTS} \
    JENKINS_OPTS=${JENKINS_OPTS} \
    SESSION_TIMEOUT=${SESSION_TIMEOUT} \
    MEMORY_ARGS=${JAVA_MEMORY_ARGS} \
    DEBUG_PORT=8500 \
    DEBUG=false \
    JENKINS_REFERENCE_DIR=${JENKINS_HOME}/share/ref \
    PATH=${JENKINS_HOME}:${PATH}

ENV JENKINS_UC=${JENKINS_UPDATE_CENTER} \
    JENKINS_UC_EXPERIMENTAL="${JENKINS_UPDATE_CENTER}/experimental" \
    JENKINS_UC_DOWNLOAD="${JENKINS_UPDATE_CENTER}/download" \
    JENKINS_WAR=${JENKINS_REFERENCE_DIR}/jenkins.war \
    CASC_JENKINS_CONFIG=${JENKINS_HOME}/shared/casc_configs \
    INIT_GROOVY_D=${JENKINS_REFERENCE_DIR}/init.groovy.d \
    INIT_CONFIG_D=${JENKINS_REFERENCE_DIR}/init.config.d \
    COPY_REFERENCE_FILE_LOG=${JENKINS_HOME}/copy_reference_file.log \
    JENKINS_PLUGIN_DIRECTORY="${JENKINS_REFERENCE_DIR}/plugins"

# Copy certificates to truststore
COPY nginx/certs/* ${CERTS_ANCHORS}/

# Copy all important files to JENKINS_REFERENCE_DIR
COPY log.properties plugins.txt non_casc_compatible_plugins_conf ${JENKINS_REFERENCE_DIR}/
COPY init.groovy.d/* ${JENKINS_REFERENCE_DIR}/init.groovy.d/

# Copy shell scripts
COPY shell_scripts/jenkins-support.sh /usr/local/bin/jenkins-support.sh
COPY shell_scripts/tini-shim.sh /bin/tini

# Copy starter and change perms
COPY shell_scripts/jenkins.sh /usr/local/bin/jenkins.sh

# Get jenkins.war from local repository
ADD ${JENKINS_WAR_CENTER}/war/${JENKINS_VERSION}/jenkins.war ${JENKINS_REFERENCE_DIR}/jenkins.war

# Get plugin manager from github
ADD ${PLUGIN_MANAGER_URL}/${PLUGIN_MANAGER_VERSION}/jenkins-plugin-manager-${PLUGIN_MANAGER_VERSION}.jar \
    ${JENKINS_REFERENCE_DIR}/jenkins-plugin-manager.jar

# Copy repositories to yum repo directory
COPY yum.repos.d/adoptopenjdk.repo yum.repos.d/centos.repo /etc/yum.repos.d/

#################################### Install utils ###########################
# Jenkins is run with USER `jenkins`, uid = 1000, guid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p ${JENKINS_HOME} ${JENKINS_REFERENCE_DIR} \
    && groupadd -g ${GID} ${GROUP} \
    && useradd -d "${JENKINS_HOME}" -u ${UID} -g ${GID} -m -s /bin/bash ${USER} \
    && chown -R ${UID}:${GID} ${JENKINS_HOME} \
    && yum -y install wget unzip vim git iputils adoptopenjdk-11-openj9 \
    && yum clean all \
    && rm -rf /var/cache/dnf \
    && update-ca-trust -f \
    && keytool -import -alias ${VAULT_DOMAIN} -cacerts -storepass changeit -noprompt -file ${CERTS_ANCHORS}/${VAULT_DOMAIN}.pem \
    && keytool -import -alias ${JENKINS_DOMAIN} -cacerts -storepass changeit -noprompt -file ${CERTS_ANCHORS}/${JENKINS_DOMAIN}.pem

# Use tini as subreaper in Docker container to adopt zombie processes
COPY shell_scripts/tini_pub.gpg ${JENKINS_HOME}/
COPY shell_scripts/tini shell_scripts/tini.asc /sbin/
RUN gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
    && gpg --verify /sbin/tini.asc \
    && rm -rf /sbin/tini.asc /root/.gnupg \
    && chmod +x /sbin/tini

RUN java -jar ${JENKINS_REFERENCE_DIR}/jenkins-plugin-manager.jar --view-security-warnings \
    --war ${JENKINS_REFERENCE_DIR}/jenkins.war \
    --plugin-file ${JENKINS_REFERENCE_DIR}/plugins.txt \
    --jenkins-update-center ${JENKINS_UC} \
    --jenkins-experimental-update-center ${JENKINS_UC_EXPERIMENTAL} \
    --plugin-download-directory ${JENKINS_PLUGIN_DIRECTORY} \
    --latest true \
    --list

#change perms
RUN chown -R ${UID}:${GID} /data/jenkins && chmod -R +rwx ${JENKINS_HOME} && chmod +x /usr/local/bin/jenkins.sh

# Set active USER
USER ${USER}:${GROUP}

# Set working directory
WORKDIR ${JENKINS_HOME}

# Expose port for main web interface
EXPOSE ${JENKINS_MASTER_PORT}

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]
