#!/bin/sh -e

conf_dir=$(readlink -f $(dirname "$0"))
git_defs_file=${conf_dir}/gits-definitions

## Load configuration
source ${conf_dir}/backuper-configuration

if [ "${borg_enable}" == "true" ] ; then
    git_clone_dir=${clone_tmp_dir}
else
    git_clone_dir=${backup_dir}
fi

git_deph_compute_args () {
    if [ -n "${git_deph}" ] ; then
        echo -n "--depth=${git_deph}"
    fi
}

cat ${git_defs_file} | grep -vE '^#' | while IFS=',' read git_url git_deph ; do

    url_protocol=${git_url%%:*}
    git_name=${git_url##*/}
    git_name=${git_name%%.*}
    git_borg_dir=${backup_dir}/${git_name}

    echo Processing git $git_url
    ## Create Borg repository if needed
    if [ ${borg_enable} == "true" -a ! -e "${git_borg_dir}" ] ; then
        borg init -e repokey ${git_borg_dir}
    fi

    cd ${git_clone_dir}
    if [ "${url_protocol}" = 'https' -o "${url_protocol}" = 'http' ] ; then
        if [ -e "${git_name}" ] ; then
            cd ${git_name}
            git pull $(git_deph_compute_args)
        else 
            git clone $(git_deph_compute_args) ${git_url} ${git_name}
            cd ${git_name}
        fi
         git submodule foreach --recursive update
    else
        echo "Unsupported url protocol, exiting ..." >&2
        exit 2
    fi

    if [ "${borg_enable}" == "true" ]; then
        cd ..
        for try in 1 2 3 ; do
            set +e
            borg create -v --files-cache="ctime,size" "${git_borg_dir}::"'{now:%Y-%m-%d-%H-%M}' "./${git_name}"
            backup_rs=$?
            set -e
            if [ ${backup_rs} -eq 0 ] ; then
                borg prune -v --list ${borg_prune_keep_args} ${git_borg_dir}
                borg compact -v --cleanup-commits ${git_borg_dir}
                break
            fi
        done
        if [ ${backup_rs} -ne 0 ] ; then
            echo "Error in backup exiting ..." >&2
            exit 2
        fi
    fi
done