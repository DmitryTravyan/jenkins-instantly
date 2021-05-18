#!/bin/bash -e

###Color vars for log func###
GREEN_COLOR="\033[32m"
RED_COLOR="\033[31m"
NORMAL_COLOR="\033[0;39m"
######

log () {
    echo -e "${GREEN_COLOR}[$(date --rfc-3339=seconds)]:${NORMAL_COLOR} $*"
}

dry_run="${1:-false}"

address="0.0.0.0"

#: "${JENKINS_WAR:="/data/jenkins/share/jenkins.war"}"
#: "${JENKINS_HOME:="/data/jenkins/home"}"

[ $(stat -c %U "$JENKINS_HOME") == "jenkins" ] || chown -R jenkins "$JENKINS_HOME"

if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then

    touch "${COPY_REFERENCE_FILE_LOG}" || { echo -e "\e[31mCan not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?\e[0m"; exit 1; }
    echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"

    if [ -d ${JENKINS_REFERENCE_DIR}/ ]; then
        log "Synchronize ${JENKINS_REFERENCE_DIR}/ to ${JENKINS_HOME}:"
        find ${JENKINS_REFERENCE_DIR} \( -type f -o -type l \) -exec bash -c '. /usr/local/bin/jenkins-support.sh; for arg; do copy_reference_file "$arg"; done' _ {} +
        log "Sync ${JENKINS_REFERENCE_DIR}/ to ${JENKINS_HOME} complete"
    else
        log -ne "Directory ${JENKINS_REFERENCE_DIR} not found, skipping synchronization!" >&2
    fi

    # Jenkins args
    jar_args=""
    # Java args
    java_args="-Djava.awt.headless=true -Dhudson.TcpSlaveAgentListener.hostName=jenkins-master"

    # Memory
    java_args="$java_args $MEMORY_ARGS"

    # Session timeout
    jar_args="--sessionTimeout=$SESSION_TIMEOUT"

    echo "### --- Jenkins Starter --- ###"

    # Http/Https
    if [ "$HTTPS_ENABLE" = true ]; then
        #If keystore file not found, https will not be used
        if [ -f "$HTTPS_KEY_STORE" ]; then
        echo "### Keystore found: ${HTTPS_KEY_STORE}, Jenkins will listen https at port ${HTTPS_PORT}"
        jar_args="$jar_args --httpPort=-1 --httpsPort=$HTTPS_PORT --httpsListenAddress=$address --httpsKeyStore=$HTTPS_KEY_STORE --httpsKeyStorePassword=$HTTPS_KEY_STORE_PASSWORD"
        fi
    else
        echo "### Jenkins will listen http at port ${HTTP_PORT}"
        jar_args="$jar_args --httpPort=$HTTP_PORT --httpListenAddress=$address"
    fi

    # Debug
    if [ "$DEBUG" = true ]; then
        echo "### Debug mode enabled"
        jar_args="$jar_args -Xdebug -Xrunjdwp:transport=dt_socket,address=$DEBUG_PORT,server=y,suspend=n"
    fi

    # Prefix
    if [ "$PREFIX" != "" ]; then
        echo "### Using prefix ${PREFIX}"
        jar_args="$jar_args --prefix=$PREFIX"
    fi

    # Read additional JAVA_OPTS and JENKINS_OPTS
    echo "Show userdefined java opts: ${JAVA_OPTS}"
    java_opts_array=()
    while IFS= read -r -d '' item; do
        java_opts_array+=( "$item" )
    done < <([[ $JAVA_OPTS ]] && xargs printf '%s\0' <<<"$JAVA_OPTS")

    jenkins_opts_array=()
    while IFS= read -r -d '' item; do
        jenkins_opts_array+=( "$item" )
    done < <([[ $JENKINS_OPTS ]] && xargs printf '%s\0' <<<"$JENKINS_OPTS")

    #Add JENKINS_OPTS to jar args
    jar_args="$jar_args ${jenkins_opts_array[@]}"
    echo "### Jar arguments: ${jar_args}"

    #Add JAVA_OPTS to java args
    java_args="$java_args ${java_opts_array[@]}"
    echo "### Java arguments: ${java_args}"

    if [ "${dry_run}" = false ]; then
        cmd="exec java -Duser.home=$JENKINS_HOME $java_args -jar ${JENKINS_WAR} $jar_args"
        echo "### Starting jenkins: running command [${cmd}]"
        exec java -Duser.home="$JENKINS_HOME" $java_args -jar "${JENKINS_WAR}" $jar_args
    fi
fi

git config --global http.sslVerify "false"

# As argument is not jenkins, assume user want to run his own process, for example a `bash` shell to explore this image
exec "$@"
