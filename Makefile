# This is main makefile
.DEFAULT_GOAL := help
.PHONY:

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

include .env

WORKSPACE := $(shell pwd)
VAULT_WORKSPACE := "${WORKSPACE}/vault"
JENKINS_WORKSPACE := "${WORKSPACE}/jenkins/shared"

define print_delimiter
	@echo ${GREEN} '---------------------------------------------------------------------------------------------' ${NC}
endef

define initialize_vault
	curl --data @vault/init.json https://vault.local/v1/sys/init > vault/shared/init_secret.json
    curl --data $(echo "{\"key\":"$(cat vault/shared/init_secret.json | jq '.keys[0]')"}") https://vault.local/v1/sys/unseal
    export VAULT_TOKEN=$(cat vault/shared/init_secret.json | jq -r .root_token) && echo $VAULT_TOKEN
    curl --header "X-Vault-Token:${VAULT_TOKEN}" --request POST --data @vault/approle.json https://vault.local/v1/sys/auth/approle
    curl --header "X-Vault-Token:${VAULT_TOKEN}" --request PUT --data @vault/system-policy.json https://vault.local/v1/sys/policies/acl/system
    curl --header "X-Vault-Token:${VAULT_TOKEN}" --request PUT --data @vault/shared-policy.json https://vault.local/v1/sys/policies/acl/shared
    curl --header "X-Vault-Token:${VAULT_TOKEN}" --request POST --data '{ "type":"kv-v2" }' https://vault.local/v1/sys/mounts/secret
	curl --header "X-Vault-Token:${VAULT_TOKEN}" --request PUT --data @vault/jenkins-role.json https://vault.local/v1/auth/approle/role/jenkins
	export ROLE_ID=$(curl --header "X-Vault-Token:${VAULT_TOKEN}" --request GET https://vault.local/v1/auth/approle/role/jenkins/role-id | jq -r .data.role_id)
	export SECRET_ID=$(curl --header "X-Vault-Token:${VAULT_TOKEN}" --request POST https://vault.local/v1/auth/approle/role/jenkins/secret-id | jq -r .data.secret_id)
endef

#Print help message
help: ## get help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

dc-build: dc-build-jenkins dc-build-nginx dc-build-vault ## build container using docker-compose

dc-build-jenkins:
	@docker build --progress=plain --force-rm \
	--build-arg JENKINS_NAME=${JENKINS_NAME} \
	--build-arg JENKINS_VERSION=${JENKINS_VERSION} \
	--build-arg JENKINS_DOMAIN=${JENKINS_DOMAIN} \
	--build-arg JENKINS_MASTER_PORT=${JENKINS_MASTER_PORT} \
	--build-arg SLAVE_PORT=${SLAVE_PORT} \
	--build-arg USER=${USER} \
	--build-arg GROUP=${GROUP} \
	--build-arg UID=${UID} \
	--build-arg GID=${GID} \
	--build-arg JENKINS_HOME=${JENKINS_HOME} \
	--build-arg JENKINS_WAR_CENTER=${JENKINS_WAR_CENTER} \
	--build-arg JENKINS_UPDATE_CENTER=${JENKINS_UPDATE_CENTER} \
	--build-arg PLUGIN_MANAGER_URL=${PLUGIN_MANAGER_URL} \
	--build-arg PLUGIN_MANAGER_VERSION=${PLUGIN_MANAGER_VERSION} \
	--build-arg JAVA_OPTS=${JAVA_OPTS} \
	--build-arg JAVA_MEMORY_ARGS=${JAVA_MEMORY_ARGS} \
	--build-arg CERTS_ANCHORS=${CERTS_ANCHORS} \
	--build-arg SESSION_TIMEOUT=${SESSION_TIMEOUT} \
	--build-arg VAULT_DOMAIN=${VAULT_DOMAIN} \
	-t ${JENKINS_NAME}:${JENKINS_VERSION} .

dc-build-nginx:
	@docker build --progress=plain --force-rm \
	-f nginx/Dockerfile \
	--build-arg NGINX_VERSION=${NGINX_VERSION} \
	--build-arg JENKINS_MASTER_PORT=${JENKINS_MASTER_PORT} \
	--build-arg VAULT_PORT=${VAULT_PORT} \
	-t ${NGINX_NAME}:${NGINX_VERSION} .

dc-build-vault:
	@docker build --progress=plain --force-rm \
	-f vault/Dockerfile \
	--build-arg VAULT_NAME=${VAULT_NAME} \
	--build-arg VAULT_VERSION=${VAULT_VERSION} \
	--build-arg VAULT_PORT=${VAULT_PORT} \
	--build-arg VAULT_DOMAIN=${VAULT_DOMAIN} \
	--build-arg VAULT_TOKEN=${VAULT_TOKEN} \
	-t ${VAULT_NAME}:${VAULT_VERSION} .

dc-build-no-cache: dc-build-jenkins-no-cache dc-build-nginx-no-cache dc-build-vault-no-cache ## build container with 'no cache' option

dc-build-jenkins-no-cache:
	@docker --debug build --progress=plain --force-rm --no-cache \
	--build-arg JENKINS_NAME=${JENKINS_NAME} \
	--build-arg JENKINS_VERSION=${JENKINS_VERSION} \
	--build-arg JENKINS_DOMAIN=${JENKINS_DOMAIN} \
	--build-arg JENKINS_MASTER_PORT=${JENKINS_MASTER_PORT} \
	--build-arg SLAVE_PORT=${SLAVE_PORT} \
	--build-arg USER=${USER} \
	--build-arg GROUP=${GROUP} \
	--build-arg UID=${UID} \
	--build-arg GID=${GID} \
	--build-arg JENKINS_HOME=${JENKINS_HOME} \
	--build-arg JENKINS_WAR_CENTER=${JENKINS_WAR_CENTER} \
	--build-arg JENKINS_UPDATE_CENTER=${JENKINS_UPDATE_CENTER} \
	--build-arg PLUGIN_MANAGER_URL=${PLUGIN_MANAGER_URL} \
	--build-arg PLUGIN_MANAGER_VERSION=${PLUGIN_MANAGER_VERSION} \
	--build-arg JAVA_OPTS=${JAVA_OPTS} \
	--build-arg JAVA_MEMORY_ARGS=${JAVA_MEMORY_ARGS} \
	--build-arg CERTS_ANCHORS=${CERTS_ANCHORS} \
	--build-arg SESSION_TIMEOUT=${SESSION_TIMEOUT} \
	--build-arg VAULT_DOMAIN=${VAULT_DOMAIN} \
	-t ${JENKINS_NAME}:${JENKINS_VERSION} .

dc-build-nginx-no-cache:
	@docker --debug build --progress=plain --force-rm --no-cache \
	-f nginx/Dockerfile \
	--build-arg NGINX_VERSION=${NGINX_VERSION} \
	--build-arg JENKINS_MASTER_PORT=${JENKINS_MASTER_PORT} \
	--build-arg VAULT_PORT=${VAULT_PORT} \
	-t ${NGINX_NAME}:${NGINX_VERSION} .

dc-build-vault-no-cache:
	@docker build --progress=plain --force-rm --no-cache \
	-f vault/Dockerfile \
	--build-arg VAULT_NAME=${VAULT_NAME} \
	--build-arg VAULT_VERSION=${VAULT_VERSION} \
	--build-arg VAULT_PORT=${VAULT_PORT} \
	--build-arg VAULT_DOMAIN=${VAULT_DOMAIN} \
	--build-arg VAULT_TOKEN=${VAULT_TOKEN} \
	-t ${VAULT_NAME}:${VAULT_VERSION} .

dc-start: dc-create-network dc-start-jenkins dc-start-vault dc-start-nginx ## start container with params defined in .env
	$(call print_delimiter)
	@docker ps

dc-create-network:
	@docker network create --subnet=${NETWORK_SUBNET} ${NETWORK_ARGS} ${NETWORK_NAME}

dc-start-jenkins:
	@docker run -d \
	-v ${JENKINS_WORKSPACE}:/data/jenkins/shared \
	-p ${SLAVE_PORT}:${SLAVE_PORT} \
	--net ${NETWORK_NAME} ${JENKINS_MASTER_NETWORK_ARGS} \
	--ip ${JENKINS_MASTER_IP} \
	--add-host ${JENKINS_DOMAIN}:${NGINX_IP} \
	--add-host ${VAULT_DOMAIN}:${NGINX_IP} \
	--name ${JENKINS_NAME} \
	${JENKINS_NAME}:${JENKINS_VERSION}

dc-start-nginx:
	@docker run -d \
	-p 443:443 \
	-p ${JENKINS_MASTER_PORT}:${JENKINS_MASTER_PORT} \
	-p ${VAULT_PORT}:${VAULT_PORT} \
	--net ${NETWORK_NAME} \
	--ip ${NGINX_IP} \
	--name ${NGINX_NAME} \
	${NGINX_NAME}:${NGINX_VERSION}

dc-start-vault:
	@docker run -d \
	--cap-add=IPC_LOCK \
	-v ${VAULT_WORKSPACE}:/data/vault \
	--net ${NETWORK_NAME} \
	--ip ${VAULT_IP} \
	--add-host ${JENKINS_DOMAIN}:${NGINX_IP} \
	--add-host ${VAULT_DOMAIN}:${NGINX_IP} \
	--name ${VAULT_NAME} \
	${VAULT_NAME}:${VAULT_VERSION}

dc-init-vault:
	$(call initialize_vault)

dc-clean-start: dc-clean dc-start ## Start with cleaning all old containers

dc-up: ## launching if existing containers of same name
	@docker container start ${JENKINS_MASTER_NAME}
	@docker container top ${JENKINS_MASTER_NAME}
	@docker container start ${JENKINS_NGINX_CONTAINER_NAME}
	@docker container top ${JENKINS_NGINX_CONTAINER_NAME}

dc-logs: ## show container logs
	@docker logs ${JENKINS_MASTER_NAME}
	$(call print_delimiter)
	@docker logs ${JENKINS_NGINX_CONTAINER_NAME}

dc-stop: ## stop container
	@docker stop ${JENKINS_MASTER_NAME}
	@docker stop ${JENKINS_NGINX_CONTAINER_NAME}

dc-clean: ## remove all stopped containers
	@docker container prune -f
	@docker network prune -f

dc-destroy: dc-stop dc-clean ## stop containers and remove all stopped containers

dc-attach-jenkins: ## attach to running jenkins master container
	@docker exec -it ${JENKINS_MASTER_NAME} /bin/bash

dc-attach-jenkins-nginx: ## attach to running jenkins nginx container
	@docker exec -it ${JENKINS_NGINX_CONTAINER_NAME} /bin/bash

dc-attach-vault: ## attach to running bitbucket container
	@docker exec -it ${VAULT_CONTAINER_NAME} /bin/bash

dc-build-slave:
	@docker build --force-rm --progress=plain --no-cache \
	--build-arg JENKINS_NAME=${JENKINS_NAME} \
	--build-arg JENKINS_DOMAIN=${JENKINS_DOMAIN} \
	--build-arg JENKINS_MASTER_PORT=${JENKINS_MASTER_PORT} \
	--build-arg SLAVE_PORT=${SLAVE_PORT} \
	--build-arg SLAVE_INIT_USER=${SLAVE_INIT_USER} \
	--build-arg SLAVE_INIT_PASSWORD=${SLAVE_INIT_PASSWORD} \
	--build-arg CERTS_ANCHORS=${CERTS_ANCHORS} \
	--build-arg VAULT_DOMAIN=${VAULT_DOMAIN} \
	-t ${SLAVE_NAME_BASE}:${JENKINS_VERSION} -f agents/Dockerfile .

dc-start-slave-all: dc-start-slave-1 dc-start-slave-2

dc-start-slave-1:
	@docker run -d -it \
	--net ${NETWORK_NAME} \
	--ip ${SLAVE_IP_1} \
	-e SLAVE_NAME=${SLAVE_NAME_1} \
	--add-host ${JENKINS_DOMAIN}:${NGINX_IP} \
	--add-host ${VAULT_DOMAIN}:${NGINX_IP} \
	--name ${SLAVE_NAME_1} \
	${SLAVE_NAME_BASE}:${JENKINS_VERSION}

dc-start-slave-2:
	@docker run -d \
	--net ${NETWORK_NAME} \
	--ip ${SLAVE_IP_2} \
	-e SLAVE_NAME=${SLAVE_NAME_2} \
	--add-host ${JENKINS_DOMAIN}:${NGINX_IP} \
	--add-host ${VAULT_DOMAIN}:${NGINX_IP} \
	--name ${SLAVE_NAME_2} \
	${SLAVE_NAME_BASE}:${JENKINS_VERSION}
