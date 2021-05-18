#!/bin/bash -eu

###Color vars for log func###
GREEN_COLOR="\033[32m"
RED_COLOR="\033[31m"
NORMAL_COLOR="\033[0;39m"
######

log () {
    echo -e "${GREEN_COLOR}[$(date --rfc-3339=seconds)]:${NORMAL_COLOR} $*"
}

# compare if version1 < version2
versionLT() {
    local v1; v1=$(echo "$1" | cut -d '-' -f 1 )
    local q1; q1=$(echo "$1" | cut -s -d '-' -f 2- )
    local v2; v2=$(echo "$2" | cut -d '-' -f 1 )
    local q2; q2=$(echo "$2" | cut -s -d '-' -f 2- )
    if [ "$v1" = "$v2" ]; then
        if [ "$q1" = "$q2" ]; then
            return 1
        else
            if [ -z "$q1" ]; then
                return 1
            else
                if [ -z "$q2" ]; then
                    return 0
                else
                    [  "$q1" = "$(echo -e "$q1\n$q2" | sort -V | head -n1)" ]
                fi
            fi
        fi
    else
        [  "$v1" = "$(echo -e "$v1\n$v2" | sort -V | head -n1)" ]
    fi
}

# returns a plugin version from a plugin archive
get_plugin_version() {
    local archive; archive=$1
    local version; version=$(unzip -p "$archive" META-INF/MANIFEST.MF | grep "^Plugin-Version: " | sed -e 's#^Plugin-Version: ##')
    version=${version%%[[:space:]]}
    echo "$version"
}

# Copy files from jenkins_home_custom/ into $JENKINS_HOME
# So the initial JENKINS-HOME is set with expected content.
# Don't override, as this is just a reference setup, and use from UI
# can then change this, upgrade plugins, etc.
copy_reference_file() {
    f="${1%/}"
    b="${f%.override}"
    root_dir=${JENKINS_REFERENCE_DIR}
    len=${#root_dir}
    rel="${b:len}"
    version_marker="${rel}.version_from_image"
    dir=$(dirname "${b}")
    local action;
    local reason;
    local container_version;
    local image_version;
    local marker_version;
    local log; log=true
    if [[ ${rel} == plugins/*.jpi ]]; then
        container_version=$(get_plugin_version "$JENKINS_HOME/${rel}")
        image_version=$(get_plugin_version "${f}")
        if [[ -e $JENKINS_HOME/${version_marker} ]]; then
            marker_version=$(cat "$JENKINS_HOME/${version_marker}")
            if versionLT "$marker_version" "$container_version"; then
                if ( versionLT "$container_version" "$image_version" && [[ -n $PLUGINS_FORCE_UPGRADE ]]); then
                    action="UPGRADED"
                    reason="Manually upgraded version ($container_version) is older than image version $image_version"
                    log=true
                else
                    action="SKIPPED"
                    reason="Installed version ($container_version) has been manually upgraded from initial version ($marker_version)"
                    log=true
                fi
            else
                if [[ "$image_version" == "$container_version" ]]; then
                    action="SKIPPED"
                    reason="Version from image is the same as the installed version $image_version"
                else
                    if versionLT "$image_version" "$container_version"; then
                        action="SKIPPED"
                        log=true
                        reason="Image version ($image_version) is older than installed version ($container_version)"
                    else
                        action="UPGRADED"
                        log=true
                        reason="Image version ($image_version) is newer than installed version ($container_version)"
                    fi
                fi
            fi
        else
            if [[ -n "$TRY_UPGRADE_IF_NO_MARKER" ]]; then
                if [[ "$image_version" == "$container_version" ]]; then
                    action="SKIPPED"
                    reason="Version from image is the same as the installed version $image_version (no marker found)"
                    # Add marker for next time
                    echo "$image_version" > "$JENKINS_HOME/${version_marker}"
                else
                    if versionLT "$image_version" "$container_version"; then
                        action="SKIPPED"
                        log=true
                        reason="Image version ($image_version) is older than installed version ($container_version) (no marker found)"
                    else
                        action="UPGRADED"
                        log=true
                        reason="Image version ($image_version) is newer than installed version ($container_version) (no marker found)"
                    fi
                fi
            fi
        fi
        if [[ ! -e $JENKINS_HOME/${rel} || "$action" == "UPGRADED" || $f = *.override ]]; then
            action=${action:-"INSTALLED"}
            log=true
            mkdir -p "$JENKINS_HOME/${dir:len}"
            cp -pr "${f}" "$JENKINS_HOME/${rel}";
            # pin plugins on initial copy
            touch "$JENKINS_HOME/${rel}.pinned"
            echo "$image_version" > "$JENKINS_HOME/${version_marker}"
            reason=${reason:-$image_version}
        else
            action=${action:-"SKIPPED"}
        fi
    else
        if [[ ! -e $JENKINS_HOME/${rel} || $f = *.override ]]
        then
            action="INSTALLED"
            log=true
            mkdir -p "$JENKINS_HOME/${dir:len}"
            cp -pr "$(realpath "${f}")" "$JENKINS_HOME/${rel}";
        else
            ## User defined condition to reinstal non plugin files
            echo "rel: ${rel}, f: ${f}" >> "$COPY_REFERENCE_FILE_LOG"
            source_file_path=${f}
            target_file_path=${JENKINS_HOME}/${rel}
            if check_cksum ${source_file_path} ${target_file_path}
            then
                echo "result: $?" >> "$COPY_REFERENCE_FILE_LOG"
                action="SKIPPED"
            else
                echo "result: $?" >> "$COPY_REFERENCE_FILE_LOG"
                cp -p ${f} ${JENKINS_HOME}/${rel}
                action="REINSTALLED"
                reason="there were changes in ${source_file} since last run"
            fi
        fi
    fi
    if [[ -n "$VERBOSE" || "$log" == "true" ]]; then
        if [ -z "$reason" ]; then
            echo "$action $rel" >> "$COPY_REFERENCE_FILE_LOG"
        else
            echo "$action $rel : $reason" >> "$COPY_REFERENCE_FILE_LOG"
        fi
    fi
}

# Retries a command a configurable number of times with backoff.
#
# The retry count is given by ATTEMPTS (default 60), the initial backoff
# timeout is given by TIMEOUT in seconds (default 1.)
#
function retry_command() {
  local max_attempts=${ATTEMPTS-3}
  local timeout=${TIMEOUT-1}
  local success_timeout=${SUCCESS_TIMEOUT-1}
  local max_success_attempt=${SUCCESS_ATTEMPTS-1}
  local attempt=0
  local success_attempt=0
  local exitCode=0

  while (( attempt < max_attempts ))
  do
    set +e
    "$@"
    exitCode=$?
    set -e

    if [[ $exitCode == 0 ]]
    then
      success_attempt=$(( success_attempt + 1 ))
      if (( success_attempt >= max_success_attempt))
      then
        break
      else
        sleep "$success_timeout"
        continue
      fi
    fi

    echo "$(date -u '+%T') Failure ($exitCode) Retrying in $timeout seconds..." 1>&2
    sleep "$timeout"
    success_attempt=0
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout ))
  done

  if [[ $exitCode != 0 ]]
  then
    echo "$(date -u '+%T') Failed in the last attempt ($*)" 1>&2
  fi

  return $exitCode
}

# User defined func to check non plugin files cksums
# func gets two file paths and compare files' checksums
check_cksum(){
  first_cksum=$(cksum $1 | cut -d ' ' -f 1)
  second_cksum=$(cksum $2 | cut -d ' ' -f 1)
  echo "first: ${first_cksum}. Second: ${second_cksum}" >> "$COPY_REFERENCE_FILE_LOG"
  if [[ ${first_cksum} -eq ${second_cksum} ]]
    then
      return 0
    else
      return 1
  fi
}
