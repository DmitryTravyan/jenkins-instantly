FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

USER root:root

ARG VAULT_NAME
ARG VAULT_VERSION
ARG VAULT_PORT
ARG VAULT_DOMAIN
ARG VAULT_TOKEN
ARG VAULT_ADDR

ENV VAULT_NAME=${VAULT_NAME} \
    VAULT_VERSION=${VAULT_VERSION} \
    VAULT_PORT=${VAULT_PORT} \
    VAULT_DOMAIN=${VAULT_DOMAIN} \
    VAULT_TOKEN=${VAULT_TOKEN} \
    VAULT_ADDR=${VAULT_ADDR}

COPY yum.repos.d/hashicorp.repo /etc/yum.repos.d/hashicorp.repo
COPY nginx/certs/* /etc/pki/ca-trust/source/anchors/

RUN microdnf install vault-${VAULT_VERSION} curl iputils vim \
    && microdnf clean all \
    && groupadd -g 11160 jenkins \
    && useradd -u 11160 -g 11160 -m -s /bin/bash jenkins \
    && mkdir -p /data/vault \
    && chown -R jenkins:jenkins /data/vault /usr/bin/vault

EXPOSE ${VAULT_PORT}

WORKDIR /data/vault

USER jenkins:jenkins

ENTRYPOINT ["/usr/bin/vault", "server", "-config=config.hcl"]
