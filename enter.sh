#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} - Enter FCOS container." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -c --check    - Run shellcheck." >&2
	echo "  -h --help     - Show this help and exit." >&2
	echo "  -v --verbose  - Verbose execution." >&2
	echo "  --docker-args - Extra Docker run args. Default: '${docker_args}'." >&2
	echo "  --docker-tag  - Docker image tag. Default: '${docker_tag}'." >&2
	echo "Args:" >&2
	echo "  <user command>   - Default: '${user_cmd}'" >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="chv"
	local long_opts="help,verbose,\
docker-args:,docker-tag:,check"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-c | --check)
			check=1
			shift
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			set -x
			shift
			;;
		--docker-args)
			docker_args="${2}"
			shift 2
			;;
		--docker-tag)
			docker_tag="${2}"
			shift 2
			;;
		--)
			shift
			user_cmd="${*}"
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}

	echo "${script_name}: Done: ${result}." >&2
}

#===============================================================================
export PS4='\[\033[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}): \[\033[0;37m\]'
script_name="${0##*/}"

trap "on_exit 'Failed'" EXIT
set -e

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}
ASSEMBLER_TOP=${ASSEMBLER_TOP:-"$(cd "${SCRIPTS_TOP}/../fcos--coreos-assembler" && pwd)"}
CONFIG_TOP=${CONFIG_TOP:-"$(cd "${SCRIPTS_TOP}/../fcos--fedora-coreos-config" && pwd)"}

docker_tag=${docker_tag:-"quay.io/coreos-assembler/coreos-assembler:latest"}

process_opts "${@}"

user_cmd=${user_cmd:-"shell"}
COSA_HISTFILE=${COSA_HISTFILE:-"$(pwd)/cosa--bash-history"}

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ${check} ]]; then
	shellcheck "${0}"
	trap "on_exit 'Success'" EXIT
	exit 0
fi

#	--uidmap=1000:0:1 \
#	--uidmap=0:1:1000 \
#	--uidmap 1001:1001:64536 \

docker run --rm -ti \
	--name cosa \
	--security-opt label=disable \
	--privileged \
	-v "$(pwd)":/srv/ \
	--device /dev/fuse \
	--tmpfs /tmp \
	-v /var/tmp:/var/tmp \
	-v "${CONFIG_TOP}":/srv/src/config/:ro \
	-v "${ASSEMBLER_TOP}"/src/:/usr/lib/coreos-assembler/:ro \
	-e GITCONFIG=/srv/src/config/ \
	-e HISTFILE="${COSA_HISTFILE}" \
	"${docker_args}" \
	"${docker_tag}" \
	"${user_cmd}"

trap "on_exit 'Success'" EXIT
exit 0
