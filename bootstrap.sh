#!/usr/bin/env bash
SILVERSTRIPE_DIRECTORY="/var/www/silverstripe/"

URL="silverstripe.dev"

DB_HOST="localhost"
DB_NAME="SS_mysite"
DB_USER="silverstripe"
DB_PASSWORD="silverstripe"

TIMEZONE="Europe/Berlin"

XDEBUG_CONF=$(cat <<EOF
xdebug.remote_enable = 1
xdebug.remote_connect_back = 1
xdebug.remote_port = 9000
xdebug.scream = 0 
xdebug.cli_color = 1
xdebug.show_local_vars = 1
xdebug.max_nesting_level = 500
EOF
)

VHOST_CONF=$(cat <<EOF
<VirtualHost *:80>
	ServerName ${URL}
	ServerAdmin daniel-rose@gmx.de
	DocumentRoot /var/www/silverstripe/
	<Directory /var/www/silverstripe/>
		Options Indexes FollowSymLinks MultiViews
		AllowOverride None
		Order allow,deny
		allow from all
	</Directory>
	ErrorLog /var/log/apache2/${URL}-error.log
	LogLevel warn
	CustomLog /var/log/apache2/${URL}-access.log combined
	ServerSignature On
</VirtualHost>
EOF
)

function installComposer() {
	echo "Installing Composer"
	curl -s https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer
}

function installSilverStripe() {
	echo "Installing SilverStripe"

	mkdir ${SILVERSTRIPE_DIRECTORY}

	chown vagrant:www-data ${SILVERSTRIPE_DIRECTORY} -R
	chmod g+s ${SILVERSTRIPE_DIRECTORY} -R

	sudo -u vagrant composer create-project silverstripe/installer ${SILVERSTRIPE_DIRECTORY}
	chown vagrant:www-data ${SILVERSTRIPE_DIRECTORY} -R

	chmod g+w ${SILVERSTRIPE_DIRECTORY}assets
	chmod g+w ${SILVERSTRIPE_DIRECTORY}mysite/_config/config.yml
	chmod g+w ${SILVERSTRIPE_DIRECTORY}mysite/_config.php
	chmod g+w ${SILVERSTRIPE_DIRECTORY}.htaccess
}

echo "Adding user vagrant to group www-data"
usermod -a -G www-data vagrant

echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "Updating Ubuntu-Repositories"
apt-get update 2> /dev/null

echo "Installing Git"
apt-get install git -y 2> /dev/null

echo "Installing Apache2"
apt-get install apache2 -y 2> /dev/null

echo "Installing PHP5-FPM & PHP5-CLI"
apt-get install libapache2-mod-php5 php5-cli -y 2> /dev/null

echo "Installing PHP extensions"
apt-get install curl php5-xdebug php-apc php5-intl php5-xsl php5-curl php5-gd php5-mcrypt php5-mysql php5-tidy -y 2> /dev/null

echo "Enable rewrite-Module"
a2enmod rewrite 2> /dev/null

echo "Enable mcrypt-Module"
php5enmod mcrypt 2> /dev/null

echo "Set memory limit to 512 MB"
sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php5/apache2/php.ini 2> /dev/null

echo "Set timezone"
sed -i "s@;date.timezone =@date.timezone = '${TIMEZONE}'@" /etc/php5/cli/php.ini
sed -i "s@;date.timezone =@date.timezone = '${TIMEZONE}'@" /etc/php5/apache2/php.ini

if ! grep -q 'xdebug.remote_enable = 1' /etc/php5/mods-available/xdebug.ini; then
	echo "${XDEBUG_CONF}" >> /etc/php5/mods-available/xdebug.ini
fi

a2dissite 000-default

if [ ! -f "/etc/apache2/sites-available/${URL}.conf" ]; then
	touch "/etc/apache2/sites-available/${URL}.conf"
	echo "${VHOST_CONF}" >> "/etc/apache2/sites-available/${URL}.conf"
fi

a2ensite silverstripe.dev

echo "Restart Apache2"
service apache2 restart 2> /dev/null

echo "Installing DebConf-Utils"
apt-get install debconf-utils -y 2> /dev/null

debconf-set-selections <<< "mysql-server mysql-server/root_password password password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password password"

echo "Installing MySQL-Server"
apt-get install mariadb-server -y 2> /dev/null

echo "Creating Database"
mysql -u root --password="password" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password="password" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}'"
mysql -u root --password="password" -e "FLUSH PRIVILEGES"

debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean false'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2'
 
debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password password'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password password'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/password-confirm password password'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/setup-password password password'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/database-type select mysql'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password password'
 
debconf-set-selections <<< 'dbconfig-common dbconfig-common/mysql/app-pass password password'
debconf-set-selections <<< 'dbconfig-common dbconfig-common/mysql/app-pass password'
debconf-set-selections <<< 'dbconfig-common dbconfig-common/password-confirm password password'
debconf-set-selections <<< 'dbconfig-common dbconfig-common/app-password-confirm password password'
debconf-set-selections <<< 'dbconfig-common dbconfig-common/app-password-confirm password password'
debconf-set-selections <<< 'dbconfig-common dbconfig-common/password-confirm password password'

echo "Installing PHPMyAdmin"
apt-get install phpmyadmin -y 2> /dev/null

if [ ! -f "/usr/local/bin/composer" ]; then
	installComposer
fi

if [ ! -f "${SILVERSTRIPE_DIRECTORY}index.php" ]; then
	installSilverStripe
fi