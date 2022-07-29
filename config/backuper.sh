#!/bin/sh -e

conf_dir=$(readlink -f $(dirname "$0"))
git_defs_file=${conf_dir}/gits-definitions

## Load configuration
source ${conf_dir}/backuper-configuration

git_clone_dir=${backup_dir}

git_deph_compute_args () {
    if [ -n "${git_deph}" ] ; then
        echo -n "--depth=${git_deph}"
    fi
}

cat ${git_defs_file} | grep -vE '^#' | while IFS=',' read git_url git_deph ; do

    url_protocol=${git_url%%:*}
    git_name=${git_url##*/}
    git_name=${git_name%%.*}

    echo Processing git $git_url
    cd ${git_clone_dir}
    if [ "${url_protocol}" = 'https' -o "${url_protocol}" = 'http' ] ; then
        set -x
        if [ -e "${git_name}" ] ; then
            cd ${git_name}
            git pull $(git_deph_compute_args)
        else 
            git clone $(git_deph_compute_args) ${git_url}
            cd ${git_name}
        fi
         git submodule foreach --recursive update
    else
        echo "Unsupported url protocol, exiting ..." >&2
        exit 2
    fi
done