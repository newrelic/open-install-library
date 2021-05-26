#!/bin/bash

# Install wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
php wp-cli.phar --info
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Set up Wordpress
mkdir -p /wordpress
rm -rf /wordpress/*
cd /wordpress

echo "<?php phpinfo(); ?>"| tee test.php

# Ensure /usr/local/bin is on the path as it doesn't appear
# to be, by default, on the Linux 2 image.
if [[ ":$PATH:" != *:/usr/local/bin:* ]]; then
	export PATH=$PATH:/usr/local/bin
fi

# If on RedHat based distro, assume we are using mariadb, and
# that it needs to be started post package installation.
if [ $(which yum) ]; then
	service mariadb start
fi

mysql -u root -e \
"GRANT ALL ON *.* TO 'wp_user'@'localhost' IDENTIFIED BY 'wp_password'; \
FLUSH PRIVILEGES;"

echo WP core download.
wp core download --allow-root

echo WP core config.
wp core config --allow-root \
               --dbhost=localhost \
               --dbname=wordpress \
               --dbuser=wp_user \
               --dbpass=wp_password

echo WP db create.
wp db create --allow-root

echo WP core install.
wp core install --allow-root \
                --url={{ ip }} \
                --title="PHP Wordpress Test App" \
                --admin_name=admin \
            --admin_password=admin \
            --admin_email=admin@example.com

if [ $(which nginx) ]; then
	if [ -d /etc/nginx/sites-available ]; then
		if [ ! -f /etc/nginx/sites-available/wordpress-site ]; then
			echo Creating nginx wordpress-site config.
			cp ~/templates/wordpress-site /etc/nginx/sites-available
		fi
		if [ ! -L /etc/nginx/sites-enabled/wordpress-site ]; then
			echo Activating nginx wordpress-site config.
			ln -s /etc/nginx/sites-available/wordpress-site /etc/nginx/sites-enabled/
		fi
		if [ -L /etc/nginx/sites-enabled/default ]; then
			echo Disabling default nginx site config.
			unlink /etc/nginx/sites-enabled/default
		fi
	else
		sed -i -e "s/\/usr\/share\/nginx\/html/\/wordpress/" /etc/nginx/nginx.conf
	fi
	echo Restarting nginx.
	systemctl restart nginx
fi

if [ $(which apache2) ]; then
	SITE="wordpress"
	if [[ $(dpkg -l php-fpm) ]]; then
		echo "Using PHP FPM variant of apache2 site config."
		SITE="wordpress-fpm"

		echo Enabling proxy_fcgi.
		a2enmod proxy_fcgi
	fi
	if [ ! -f /etc/apache2/sites-available/$SITE.conf ]; then
		echo Creating apache2 wordpress site config.
		cp ~/templates/$SITE.conf /etc/apache2/sites-available
	fi
	echo Enabling apache2 wordpress site.
	a2ensite $SITE

	echo Disabling apache2 default site.
	a2dissite 000-default

	echo Enabling apache2 mod rewrite.
	a2enmod rewrite
	if [ -L /etc/apache2/sites-enabled/default ]; then
		unlink /etc/apache2/sites-enabled/default
	fi

	echo Restarting apache2.
	service apache2 reload
fi

# The presence of httpd indicates we are running on a Linux 2 host.
# The FPM / no FPM decision is made via packages in this case.
if [ $(which httpd) ]; then
	cp ~/templates/wordpress-httpd.conf /etc/httpd/conf.d/
	sed -i -e "s/DocumentRoot \"\/var\/www\/html/DocumentRoot \"\/wordpress/" /etc/httpd/conf/httpd.conf
	service httpd restart
fi
