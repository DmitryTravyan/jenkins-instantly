echo -ne "Synchronize plugins from ${pwd}/plugins to ${JENKINS_HOME}: "

if [ -d ./jenkins_home_custom ]; then
    rsync -r ./jenkins_home_custom/ $JENKINS_HOME
    if [ $? -eq 0 ]; then
        echo -ne "Sync all files to jenkins home directory: \e[32mDONE.\e[0m\r"
    else
        echo -ne "Sync all files to jenkins home directory: \e[31mERROR.\e[0m\r"
    fi
    echo -ne "\n"
else
    echo -ne "Directory ./jenkins_home_custom not found, skipping jenkins_home_custom synchronization!"
    echo -ne "\n"
fi


if [ -d ./plugins ]; then
    rsync -r ./plugins $JENKINS_HOME
    if [ $? -eq 0 ]; then
	echo -ne "Sync all files to jenkins home directory: \e[32mDONE.\e[0m\r"
    else
	echo -ne "Sync all files to jenkins home directory: \e[31mERROR.\e[0m\r"
    fi
    echo -ne "\n"
else
    echo -ne "Directory ./plugins not found, skipping plugins synchronization!"
    echo -ne "\n"
fi

echo -ne "Synchronize init scripts from ${INIT_GROOVY_D} to ${JENKINS_HOME}/init.groovy.d:"

if [ -d "${INIT_GROOVY_D}" ]; then
    if [ ! -d "${JENKINS_HOME}/init.groovy.d" ]; then
	mkdir -p "${JENKINS_HOME}/init.groovy.d"
    fi
    rsync -r ${INIT_GROOVY_D} $JENKINS_HOME
    if [ $? -eq 0 ]; then
	echo -ne "Sync all files to jenkins home directory: \e[32mDONE.\e[0m\r"
    else
	echo -ne "Sync all files to jenkins home directory: \e[31mERROR.\e[0m\r"
    fi
    echo -ne "\n"
else
    echo -ne "Directory ${INIT_GROOVY_D} not found, skipping init scripts synchronization!"
    echo -ne "\n"
fi
