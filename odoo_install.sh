#!/bin/bash
################################################################################
# 最近更新：2018-11-12
# 支持版本 Ubuntu 14.04, 15.04, 16.04 and 18.04
# Author: Yenthe Van Ginneken，https://github.com/Yenthe666/InstallScript
# Author: Ivan Deng，http://www.sunpop.cn
#-------------------------------------------------------------------------------
# 本脚本将安装Odoo到你的服务器上，支持安装多个odoo进程在一台ubuntu上，使用不同的端口
#-------------------------------------------------------------------------------
# 使用方法1，直接在主机上执行
# wget https://sunpop.cn/odoo_install.sh && bash odoo_install.sh 2>&1 | tee odoo.log
# 使用方法2，在主机上新建一个文件
# sudo nano odoo_install.sh
# 将本文中内容拷贝至该文件同时设置为可执行:
# sudo chmod +x odoo_install.sh
# 执行一键安装脚本
# bash ./odoo_install_12.sh 2>&1 | tee odoo.log
#-------------------------------------------------------------------------------
# 本脚本执行完成后，您将得到
#-------------------------------------------------------------------------------
# 1. Ubuntu 服务器更新至最新补丁
# 2. postgres 10 安装在
# 3. odoo 最新版 安装在
# 4. odoo 配置文件位于
# 5. odoo访问地址为
################################################################################

O_USER="odoo"
O_HOME="/$O_USER"
O_HOME_EXT="/$O_USER/${O_USER}-server"
# 安装 WKHTMLTOPDF，默认设置为 True ，如果已安装则设置为 False.
INSTALL_WKHTMLTOPDF="True"
# 默认 odoo 端口 8069，建议安装 nginx 做前端端口映射，这样才能使用 livechat
O_PORT="8069"
# 选择要安装的odoo版本，如: 12.0, 11.0, 10.0 或者 saas-18. 如果使用 'master' 则 master 分支将会安装
O_VERSION="12.0"
# 如果要安装odoo企业版，则在此设置为 True
IS_ENTERPRISE="False"
# 设置超管的用户名及密码
O_SUPERADMIN="admin"
# 设置 odoo 配置文件名
O_CONFIG="${O_USER}"

###  WKHTMLTOPDF 下载链接，将使用 sunpop.cn 的cdn下载以加快速度，注意主机版本及 WKHTMLTOPDF的版本
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=http://cdn.sunpop.cn/download/wkhtmltox-0.12.1_linux-trusty-amd64.deb
WKHTMLTOX_X32=http://cdn.sunpop.cn/download/wkhtmltox-0.12.1_linux-trusty-i386.deb

#--------------------------------------------------
# 更新服务器，多数要人工干预，故可以注释
#--------------------------------------------------
echo -e "\n---- Update Server ----"
# 升级服务器到 ubuntu 18，不需要可以注释
# universe package is for Ubuntu 18.x
apt install update-manager
apt-get update && sudo apt-get dist-upgrade
do-release-upgrade -d -m server -q
sudo add-apt-repository universe
sudo apt-get update
sudo apt-get upgrade -y
# end 升级 ubuntu 18

#--------------------------------------------------
# 安装 PostgreSQL Server 10.0
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL 10 Server ----"
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ xenialc-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt-get install wget ca-scertificates
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
sudo apt-get update
sudo apt-get install postgresql-10 -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $O_USER" 2> /dev/null || true

#--------------------------------------------------
# 安装依赖，源码安装时需要，用deb可以省
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip -y

echo -e "\n---- Install tool packages ----"
sudo apt-get install wget git bzr python-pip gdebi-core -y

echo -e "\n---- Install python packages ----"
sudo apt-get install libxml2-dev libxslt1-dev zlib1g-dev -y
sudo apt-get install libsasl2-dev libldap2-dev libssl-dev -y
sudo apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y
sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd chardet libsass

echo -e "\n---- Install python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
sudo apt-get install python3-suds

echo -e "\n--- Install other required packages"
sudo apt-get install node-clean-css -y
sudo apt-get install node-less -y
sudo apt-get install python-gevent -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 12 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$O_HOME --gecos 'ODOO' --group $O_USER
#The user should also be added to the sudo'ers group.
sudo adduser $O_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$O_USER
sudo chown $O_USER:$O_USER /var/log/$O_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $O_VERSION https://www.github.com/odoo/odoo $O_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $O_USER -c "mkdir $O_HOME/enterprise"
    sudo su $O_USER -c "mkdir $O_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $O_VERSION https://www.github.com/odoo/enterprise "$O_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $O_VERSION https://www.github.com/odoo/enterprise "$O_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $O_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo pip3 install num2words ofxparse
    sudo apt-get install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
sudo su $O_USER -c "mkdir $O_HOME/custom"
sudo su $O_USER -c "mkdir $O_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $O_USER:$O_USER $O_HOME/*

echo -e "* Create server config file"

sudo touch /etc/${O_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${O_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${O_SUPERADMIN}\n' >> /etc/${O_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${O_PORT}\n' >> /etc/${O_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${O_USER}/${O_CONFIG}.log\n' >> /etc/${O_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${O_HOME}/enterprise/addons,${O_HOME_EXT}/addons\n' >> /etc/${O_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${O_HOME_EXT}/addons,${O_HOME}/custom/addons\n' >> /etc/${O_CONFIG}.conf"
fi
sudo chown $O_USER:$O_USER /etc/${O_CONFIG}.conf
sudo chmod 640 /etc/${O_CONFIG}.conf

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $O_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $O_USER $O_HOME_EXT/openerp-server --config=/etc/${O_CONFIG}.conf' >> $O_HOME_EXT/start.sh"
sudo chmod 755 $O_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$O_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $O_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$O_HOME_EXT/odoo-bin
NAME=$O_CONFIG
DESC=$O_CONFIG
# Specify the user name (Default: odoo).
USER=$O_USER
# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${O_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Security Init File"
sudo mv ~/$O_CONFIG /etc/init.d/$O_CONFIG
sudo chmod 755 /etc/init.d/$O_CONFIG
sudo chown root: /etc/init.d/$O_CONFIG

echo -e "* Start ODOO on Startup"
sudo update-rc.d $O_CONFIG defaults

echo -e "* Starting Odoo Service"
sudo su root -c "/etc/init.d/$O_CONFIG start"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $O_PORT"
echo "User service: $O_USER"
echo "User PostgreSQL: $O_USER"
echo "Code location: $O_USER"
echo "Addons folder: $O_USER/$O_CONFIG/addons/"
echo "Start Odoo service: sudo service $O_CONFIG start"
echo "Stop Odoo service: sudo service $O_CONFIG stop"
echo "Restart Odoo service: sudo service $O_CONFIG restart"
echo "-----------------------------------------------------------"
