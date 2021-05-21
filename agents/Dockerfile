FROM registry.access.redhat.com/ubi8:latest

USER root:root

ARG JENKINS_NAME
ARG JENKINS_DOMAIN
ARG SLAVE_INIT_USER
ARG SLAVE_INIT_PASSWORD
ARG CERTS_ANCHORS
ARG VAULT_DOMAIN

ENV JENKINS_NAME=${JENKINS_NAME} \
    JENKINS_DOMAIN=${JENKINS_DOMAIN} \
    SLAVE_INIT_USER=${SLAVE_INIT_USER} \
    SLAVE_INIT_PASSWORD=${SLAVE_INIT_PASSWORD} \
    CERTS_ANCHORS=${CERTS_ANCHORS} \
    VAULT_DOMAIN=${VAULT_DOMAIN}

COPY agents/slave.sh /data/jenkins/
COPY nginx/certs/* ${CERTS_ANCHORS}/
COPY yum.repos.d/adoptopenjdk.repo /etc/yum.repos.d/adoptopenjdk.repo

RUN yum install -y vim curl iputils procps adoptopenjdk-11-openj9 git \
    && yum clean all \
    && rm -rf /var/cache/dnf \
    && update-ca-trust -f \
    && mkdir -p /data/jenkins \
    && groupadd -g 11160 jenkins \
    && useradd -d /data/jenkins -u 11160 -g 11160 -m -s /bin/bash jenkins \
    && chmod +x /data/jenkins/slave.sh \
    && chown -R 11160:11160 /data/jenkins  \
    && keytool -import -alias ${VAULT_DOMAIN} -cacerts -storepass changeit -noprompt -file ${CERTS_ANCHORS}/${VAULT_DOMAIN}.pem \
    && keytool -import -alias ${JENKINS_DOMAIN} -cacerts -storepass changeit -noprompt -file ${CERTS_ANCHORS}/${JENKINS_DOMAIN}.pem

WORKDIR /data/jenkins/

EXPOSE 443

USER jenkins:jenkins

ENTRYPOINT [ "./slave.sh" ]
