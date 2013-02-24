#!/bin/bash
#
# copyleft 2013 stefano.cudini@gmail.com
#
# scan cron files and show their in chronological order
# useful for checking the overlap of tasks
#

CRONTAB='/etc/crontab'
CRONDIR='/etc/cron.d'

tab=$(echo -en "\t")

function clean_cron_lines() {
    while read line ; do
        echo "${line}" |
            egrep --invert-match '^($|\s*#|\s*[[:alnum:]_]+=)' |
            sed --regexp-extended "s/\s+/ /g" |
            sed --regexp-extended "s/^ //"
    done;
}

function lookup_run_parts() {
    while read line ; do
        match=$(echo "${line}" | egrep -o 'run-parts (-{1,2}\S+ )*\S+')

        if [[ -z "${match}" ]] ; then
            echo "${line}"
        else
            cron_fields=$(echo "${line}" | cut -f1-6 -d' ')
            cron_job_dir=$(echo  "${match}" | awk '{print $NF}')

            if [[ -d "${cron_job_dir}" ]] ; then
                for cron_job_file in "${cron_job_dir}"/* ; do  # */ <not a comment>
                    [[ -f "${cron_job_file}" ]] && echo "${cron_fields} ${cron_job_file}"
                done
            fi
        fi
    done;
}


temp=$(mktemp) || exit 1


cat "${CRONTAB}" | clean_cron_lines | lookup_run_parts >"${temp}" 


cat "${CRONDIR}"/* | clean_cron_lines >>"${temp}"  # */ <not a comment>

while read user ; do
    crontab -l -u "${user}" 2>/dev/null |
        clean_cron_lines |
        sed --regexp-extended "s/^((\S+ +){5})(.+)$/\1${user} \3/" >>"${temp}"
done < <(cut --fields=1 --delimiter=: /etc/passwd)

cat "${temp}" |
    sed --regexp-extended "s/^(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(\S+) +(.*)$/\1\t\2\t\3\t\4\t\5\t\6\t\7/" |
    sort --numeric-sort --field-separator="${tab}" --key=2 --key=1 |
#    sed "1i\mi\th\td\tm\tw\tuser\tcommand" |
    column -s"${tab}" -t

rm --force "${temp}"
