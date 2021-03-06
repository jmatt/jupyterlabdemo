#!/bin/sh
export DEBUG=1
if [ -n "${DEBUG}" ]; then
    set -x
fi
sync
cd ${HOME}
cmd="python3 /usr/bin/jupyter-singlelabuser \
     --ip='*' --port=8888 --debug \
     --hub-api-url=${JPY_HUB_API_URL} \
     --notebook-dir=${HOME}/notebooks \
     --LabApp.base_url=/user/${USER}"
echo ${cmd}
if [ -n "${DEBUG}" ]; then
    while : ; do
	${cmd}
	d=$(date)
	echo "${d}: sleeping."
	sleep 60
    done
else    
    exec ${cmd}
fi
