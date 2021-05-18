FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

ARG NGINX_VERSION
ARG JENKINS_PORT
ARG VAULT_PORT

ENV NGINX_VERSION=${NGINX_VERSION} \
    JENKINS_PORT=${JENKINS_PORT} \
    VAULT_PORT=${VAULT_PORT}

COPY yum.repos.d/nginx.repo /etc/yum.repos.d/nginx.repo
COPY nginx/certs/* /etc/pki/ca-trust/source/anchors/
COPY nginx/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443 ${JENKINS_PORT} ${VAULT_PORT}

RUN microdnf install nginx-${NGINX_VERSION} vim curl iputils procps \
    && update-ca-trust -f \
    && microdnf clean all \
    && mkdir -p /data/nginx/log \
    && groupadd -g 11160 jenkins \
    && useradd -d /data/nginx -u 11160 -g 11160 -m -s /bin/bash jenkins \
    && chown -R 11160:11160 /data/nginx /etc/pki/ca-trust/source/anchors /usr/share/nginx /etc/nginx /var/cache/nginx

USER jenkins:jenkins

ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]
