#!/bin/bash

function setup_user() {
    id -u ${U_NAME} 2> /dev/null 1>&2
    if [ $? -ne 0 ]; then
	make_user
    fi
    setup_git
}

function make_user() {
    # If GITHUB_ID is not set, then we rely on sqrekubespawner/GHOWLAuth
    #  to have named the pod correctly.  Failing that we just use the
    #  standard system generated UID.
    # We would like the pod named jupyter-<user>-<githubid>
    # If we can get a good value, the UID and GID will both be that.
    local nuid=""
    if [ -z "${GITHUB_ID}" ]; then
	last=$(hostname | cut -d '-' -f 3)
	case ${last} in
	    ''|*[!0-9]*)
		GITHUB_ID=""
		;;
	    *)
		GITHUB_ID=${last}
		;;
	esac
    fi
    # Reject implausibly small values.  Probably means
    #  regular kubespawner, and thus we got "1"
    if [ "${GITHUB_ID}" -lt 10 ]; then
	GITHUB_ID=""
    fi
    if [ -n "${GITHUB_ID}" ]; then
	nuid="-u ${GITHUB_ID} -g ${U_NAME}"
    fi
    add_groups
    local gentry=""
    local suppgrp=""
    if [ -n "${GITHUB_ORGANIZATIONS}" ]; then
	for gentry in $(echo ${GITHUB_ORGANIZATIONS} | tr "," "\n"); do
	    gname=$(echo ${gentry} | cut -d ':' -f 1)
	    if [ -z "${suppgrp}" ]; then
		suppgrp="-G ${gname}"
	    else
		suppgrp="${suppgrp},${gname}"
	    fi
	done
    fi
    homedir="${HOMEDIRS}/${U_NAME}"
    makedir="-m"
    if [ -e "${homedir}" ]; then
	makedir="-M"
    fi
    adduser ${U_NAME} -d ${homedir} -c '' -N -g ${U_NAME} ${nuid} \
      ${suppgrp} ${makedir} -s ${DEFAULT_SHELL}
}

function add_groups() {
    add_group ${U_NAME} ${GITHUB_ID}
    local gentry=""
    local gname=""
    local gid=""
    if [ -n "${GITHUB_ORGANIZATIONS}" ]; then
        for gentry in $(echo ${GITHUB_ORGANIZATIONS} | tr "," "\n"); do
            gname=$(echo ${gentry} | cut -d ':' -f 1)
            gid=$(echo ${gentry} | cut -d ':' -f 2)
            add_group ${gname} ${gid}
        done
    fi
}

function add_group() {
    # If the group exists already, use that.
    # If it doesn't exist but the group id is in use, use a system-
    #  assigned gid.
    # Otherwise, use the group id to create the group.
    local gname=$1
    local gid=$2
    local exgrp=$(getent group ${gname})
    if [ -n "${exgrp}" ]; then
        return
    fi
    if [ -n "${gid}" ]; then
        local exgid=$(getent group ${gid})
        if [ -n "${exgid}" ]; then
            gid=""
        fi
    fi
    local gopt=""
    if [ -n "${gid}" ]; then
        gopt="-g ${gid}"
    fi
    groupadd ${gopt} ${gname}
}

function setup_git() {
    if [ -n "${GITHUB_ACCESS_TOKEN}" ]; then
        local entry="https://${U_NAME}:${GITHUB_ACCESS_TOKEN}@github.com"
        local file="${HOMEDIRS}/${U_NAME}/.git-credentials"
        if [ ! -e "${file}" ]; then
            echo "${entry}" > ${file}
            chmod 0600 ${file}
            chown ${U_NAME}:${U_NAME} ${file}
        fi
    fi
    if [ ! -e "${gitcfg}" ]; then
        local gitcfg="${HOMEDIRS}/${U_NAME}/.gitconfig"
	touch ${gitcfg}
	if [ -n "${GITHUB_NAME}" ] || [ -n "${GITHUB_EMAIL}" ]; then
	    echo "[user]" >> ${gitcfg}
	    if [ -n "${GITHUB_NAME}" ]; then
		echo "    name = ${GITHUB_NAME}" >> ${gitcfg}
	    fi
	    if [ -n "${GITHUB_EMAIL}" ]; then
		echo "    email = ${GITHUB_EMAIL}" >> ${gitcfg}
	    fi
	fi
	echo "[push]" >> ${gitcfg}
	echo "    default = simple" >> ${gitcfg}
        echo "[credential]" >> ${gitcfg}
        echo "    helper = store" >> ${gitcfg}
        chown ${U_NAME}:${U_NAME} ${gitcfg}
    fi
}

## Begin mainline code. ##
U_NAME="${JPY_USER}" # Expect this to change.
HOMEDIRS="/home"
DEFAULT_SHELL="/bin/bash"
sudo=""
if [ $(id -u) -eq 0 ]; then
    if [ -n "${U_NAME}" ]; then
	setup_user
	sudo="sudo -E -u ${U_NAME} "
    else
	echo 1>&2 "Warning: running as UID 0"
    fi
fi
exec ${sudo} /opt/lsst/software/jupyterlab/runlab.sh
