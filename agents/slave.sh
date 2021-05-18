#!/bin/bash

curl -L --fail "https://${JENKINS_DOMAIN}/jnlpJars/agent.jar" --output "./agent.jar"

curl --fail --user ${SLAVE_INIT_USER}:${SLAVE_INIT_PASSWORD} "https://${JENKINS_DOMAIN}/computer/${SLAVE_NAME}/slave-agent.jnlp" | sed "s/.*<application-desc main-class=\"hudson.remoting.jnlp.Main\"><argument>\([a-z0-9]*\).*/\1/" >> secret-file

java -jar agent.jar -jnlpUrl https://${JENKINS_DOMAIN}/computer/${SLAVE_NAME}/slave-agent.jnlp -secret @secret-file -workDir "/data/jenkins/"