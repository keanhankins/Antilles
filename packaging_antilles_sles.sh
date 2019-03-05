#!/bin/bash

# Copyright © 2019-present Lenovo
# 
# This file is licensed under both the BSD-3 license for individual use and
# EPL-1.0 license for commercial use. Full text of both licenses can be found in
# COPYING.BSD and COPYING.EPL files.


###################################################################
# !!! BE AWARE !!!
# Prerequisites
# python-setuptools > 30.0
###################################################################


BASE_PATH=$(cd `dirname $0`; pwd)
RPMBUILD_DIR='/root/rpmbuild'
RPMBUILD_RPM_DIR='/root/rpmbuild/RPMS'
ANTILLES_RPMS_DIR='/opt/antilles_dist_rpms'


###################################################################
# Packaging antilles-recipe: antilles-prepare
#                            antilles-rpm-macros
###################################################################

function install_antilles_recipe() {
    cd ${BASE_PATH}/antilles-recipe
    python setup.py bdist_rpm -q --binary-only
    zypper install -y dist/antilles-prepare*.noarch.rpm dist/antilles-rpm-macros*.noarch.rpm
    cp dist/antilles-prepare*.noarch.rpm dist/antilles-rpm-macros*.noarch.rpm ${ANTILLES_RPMS_DIR}
}

###################################################################
# Packaging antilles-dep: gmond-gpu-module
#                         nginx-https-config
#                         novnc
#                         slapd-ssl-config
###################################################################

function packaging_gmond_gpu_module() {
    cd ${BASE_PATH}/antilles-dep/dep/gmond-gpu-module
    cp nvidia.py nvidia.pyconf ~/rpmbuild/SOURCES
    rpmbuild --quiet -bb gmond-gpu-module.spec
    cd ${RPMBUILD_RPM_DIR}/noarch
    cp gmond-ohpc-gpu-module*.noarch.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_nginx_https_config() {
    cd ${BASE_PATH}/antilles-dep/dep/nginx-https-config
    cp https.rhel.conf https.suse.conf nginx-gencert ~/rpmbuild/SOURCES
    rpmbuild --quiet -bb nginx-https-config.spec
    cd ${RPMBUILD_RPM_DIR}/noarch
    cp nginx-https-config*.noarch.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_novnc() {
    cd ~/rpmbuild/SOURCES
    wget https://github.com/novnc/noVNC/archive/v1.0.0.tar.gz
    cd ${BASE_PATH}/antilles-dep/dep/novnc
    rpmbuild --quiet -bb novnc.spec
    cd ${RPMBUILD_RPM_DIR}/noarch
    cp novnc*.noarch.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_slapd_ssl_config() {
    cd ${BASE_PATH}/antilles-dep/dep/slapd-ssl-config
    cp base.ldif DB_CONFIG slapd-gencert slapd.rhel.conf slapd.suse.conf ~/rpmbuild/SOURCES
    rpmbuild --quiet -bb slapd-ssl-config.spec
    cd ${RPMBUILD_RPM_DIR}/noarch
    cp slapd-ssl-config*.noarch.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_antilles_dep() {
    packaging_gmond_gpu_module
    packaging_nginx_https_config
    packaging_novnc
    packaging_slapd_ssl_config
}

###################################################################
# Packaging antilles-alarm agents: mail sms wechat
###################################################################

function packaging_antilles_mail_agent() {
    cd ${BASE_PATH}/alarm/antilles-mail-agent
    python setup.py bdist_rpm -q --binary-only
    cp dist/antilles-mail-agent*.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_antilles_sms_agent() {
    cd ${BASE_PATH}/alarm/antilles-sms-agent
    python setup.py bdist_rpm -q --binary-only
    cp dist/antilles-sms-agent*.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_antilles_wechat_agent() {
    cd ${BASE_PATH}/alarm/antilles-wechat-agent
    python setup.py bdist_rpm -q --binary-only
    cp dist/antilles-wechat-agent*.rpm ${ANTILLES_RPMS_DIR}
}

function packaging_antilles_alarm() {
    packaging_antilles_mail_agent
    packaging_antilles_sms_agent
    packaging_antilles_wechat_agent
}

###################################################################
# Packaging antilles-tools
#           antilles-core
#           antilles-portal
#           antilles-confluent-proxy
#           antilles-env
###################################################################

function packaging_antilles_main_module() {

    # nodejs for antilles-portal
    zypper install -y nodejs

    for antilles_module in antilles-tools antilles-core antilles-portal antilles-confluent-proxy antilles-env
    do
        cd ${BASE_PATH}/${antilles_module}
        python setup.py bdist_rpm -q --binary-only
        cp dist/${antilles_module}*.rpm ${ANTILLES_RPMS_DIR}
    done
}

###################################################################
# Packaging antilles-monitor
###################################################################

function packaging_antilles_monitor() {
    # icinga-plugin required in sle 12P3
    zypper install -y nagios-rpm-macros

    for monitor_module in antilles-confluent-mond antilles-ganglia-mond antilles-icinga-mond antilles-icinga-plugin antilles-vnc-mond antilles-vnc-proxy
    do
        cd ${BASE_PATH}/monitor/${monitor_module}
        python setup.py bdist_rpm -q --binary-only
        cp dist/${monitor_module}*.rpm ${ANTILLES_RPMS_DIR}
    done
}

###################################################################
# Create antilles-repo
###################################################################

function config_nginx_for_antilles_repo() {
    ## install nginx for intranet zypper repo
    zypper install -y nginx
    systemctl start nginx

    cat << EOF > /etc/nginx/conf.d/antilles_repo_server.conf
server {
    listen 8090;
    server_name ${sms_ip};
    root ${ANTILLES_RPMS_DIR};
    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
EOF
    systemctl stop nginx
    nginx -s stop
    nginx
}


function create_antilles_repo() {
    ## create antilles repo
    zypper install -y createrepo
    cd ${ANTILLES_RPMS_DIR}
    createrepo ./
    cat << EOF > /etc/zypp/repos.d/antilles_base.repo 
[antilles-base]
name=antilles-base(SLE 12P3)
baseurl=http://${sms_ip}:8090/
gpgcheck=0
enabled=1
EOF

    zypper ref
}

###################################################################
# Packaging Antilles Main Function
###################################################################

# Clear Packaging directories
echo "WARNING: The following directories will be removed permanently."
echo "${RPMBUILD_DIR} ${ANTILLES_RPMS_DIR}"
read -p "Do you want to Continue[Y/N]?" answer
if [[ "${answer}" != "Y" ]] && [[ "${answer}" != "y" ]];then
    exit 0
fi
rm -rf ${RPMBUILD_DIR} ${ANTILLES_RPMS_DIR}


zypper install -y wget gcc gcc-c++ rpm-build rpm-devel rpmlint fdupes python-devel make python bash coreutils diffutils patch rpmdevtools


mkdir -p ${ANTILLES_RPMS_DIR}
# setup rpmbuild directories
rpmdev-setuptree

zypper install -y python-setuptools python-Cython

#
# devtools and recipe are required by other antilles modules
#
install_antilles_recipe     # Include: antilles-prepare antilles-rpm-macros


packaging_antilles_dep      # Include: gmond-gpu-module nginx-https-config novnc slapd_ssl_config
packaging_antilles_alarm    # Include: mail-agent sms-agent wechat-agent
packaging_antilles_main_module # Include: antilles-tools antilles-core antilles-portal antilles-confluent-proxy antilles-env
packaging_antilles_monitor  # Include confluent-mond ganglia-mond icinga-mond icinga-plugin vnc-mond vnc-proxy


# Get current host ip for antillse repo
confirm=0

while [[ "${confirm}" != "Y" && "${confirm}" != "y" ]]
do
    read -p "Please enter the currnet host IP: " sms_ip
    read -p "Confirm current host IP is ${sms_ip}? [Y/N] " confirm
    echo ${confirm}
done

config_nginx_for_antilles_repo
create_antilles_repo

echo
echo "Packaging Antilles finished."
echo "
=======================================================================

You can find all Antilles RPMs packages under ${ANTILLES_RPMS_DIR}
Antilles repo file locates /etc/zypp/repos.d/antilles_base.repo

You could distribute antiles repo file to other nodes in the cluster.
Then you could install antilles module by zypper.
"
