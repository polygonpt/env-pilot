#!/usr/bin/env bash

source <(grep = /vagrant/config/envpilot.ini | sed 's/ *= */=/g')

# RESPONSE
function response() {
    echo -e "\033[0mEnvpilot \033[0m $1"
}
#
# INSTALL WRAPPER
function installWrapper() {
    package=$1

    if [[ "$package" != "" ]]; then
        if [[ "$package" == "php5" ]]; then
            response "installing php5 and php modules..."
            sudo apt-get install -fy php5 php5-cli php5-fpm php5-intl php5-mcrypt php5-curl
            return
        fi

		if [[ "$package" == "node" ]]; then
			response "installing node & npm..."
			wget https://nodejs.org/dist/v4.2.6/node-v4.2.6.tar.gz
			tar zxvf node-v4.2.6.tar.gz
			cd node-v4.2.6
			./configure && make && sudo make install
			response "----------> done installing node & npm"
			response "installing pm2..."
			npm install --global pm2
		fi

        if [[ "$package" == "mysql" ]]; then
            source <(grep = /vagrant/config/mysql.ini | sed 's/ *= */=/g')

            response "installing mysql-server-5.6..."
            sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password toor'
            sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password toor'
            sudo apt-get install -y mysql-server-5.6  php5-mysqlnd

            response "configuring mysql..."

            Q1="CREATE USER '$user'@'localhost' IDENTIFIED BY '$pass';"
            Q2="CREATE DATABASE $database;"
            Q3="GRANT ALL ON $database.* TO '$user'@'localhost';"
            Q4="FLUSH PRIVILEGES;"

            SQL="${Q1}${Q2}${Q3}${Q4}"

            echo "$SQL" | mysql -u root -ptoor
            response "done configuring mysql..."
            return
        fi

        if [[ "$package" == "composer" ]]; then
            response "installing composer..."
            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer
            return
        fi

        if [[ "$package" == "wkhtmltopdf" ]]; then
            response "installing wkhtmltopdf..."

            apt-get install -y openssl build-essential xorg libssl-dev fontconfig xfonts-75dpi

            wget -q http://download.gna.org/wkhtmltopdf/0.12/0.12.2/wkhtmltox-0.12.2_linux-trusty-amd64.deb

            dpkg -i wkhtmltox-0.12.2_linux-trusty-amd64.deb

            apt-get -f --force-yes --yes install

            dpkg -i wkhtmltox-0.12.2_linux-trusty-amd64.deb

            response "finished installing wkhtmltopdf..."
            return
        fi

        response "installing $package..."
        sudo apt-get install -y $package
    fi
}

# UNINSTALL WRAPPER
function uninstallWrapper() {
    package=$1

    if [[ "$package" != "" ]]; then
        if [[ "$package" == "mysql" ]]; then
			response "uninstalling mysql"
            sudo apt-get remove -y mysql-server-*
			sudo apt-get purge -y mysql*
			sudo apt-get -y autoremove
			response "done uninstalling mysql"
            return
        fi

        response "uninstalling $package..."
        sudo apt-get remove -y $package
    fi
}

# PROVISION
if [ "$1" == "provision" ] ; then
    response "provisioning..."

    if [ "$hostname" != "" ] ; then
        response "setting hostname to $hostname..."
        sudo hostname $hostname
    fi

    if [ "$run_updates" == true ] ; then
        response "running update..."
        sudo apt-get update >/dev/null
    fi

    if [ "$packages" != "" ] ; then
        IFS=' ' ; for i in `echo $packages`; do
            installWrapper $i
        done
    fi

    # VHOSTS CONFIGURATION
    IFS=' ' ; for i in `echo $apps`; do
        response "$i vhost setup"

        if [[ -e "/etc/nginx/sites-available/$i" ]]; then
            rm /etc/nginx/sites-available/$i
            rm /etc/nginx/sites-enabled/$i
        fi

        cp /vagrant/config/apps/$i/vhost /etc/nginx/sites-available/$i
        ln -s /etc/nginx/sites-available/$i /etc/nginx/sites-enabled/$i
    done

    # NGINX CONFIGURATION
    response "NGINX config"

    if [[ -e "/etc/nginx/nginx.conf" ]]; then
        rm /etc/nginx/nginx.conf
    fi

	if [[ -d "/etc/nginx/ssl" ]]; then
		rm -R /etc/nginx/ssl
	fi

    ln -s /vagrant/config/nginx.conf /etc/nginx/nginx.conf

	if [[ -d "/vagrant/ssl" ]]; then
		ln -s /vagrant/ssl /etc/nginx/ssl
	fi

    # PHP CONFIGURATION
    response "PHP config"

    if [[ -e "/etc/php5/fpm/php.ini" ]]; then
        rm /etc/php5/fpm/php.ini
    fi

    ln -s /vagrant/config/php.ini /etc/php5/fpm/php.ini

    # RESTART NGINX
    sudo service nginx restart

    # RESTART PHP
    sudo service php5-fpm restart

    # REMOVE LOCALES WARNING
    sudo touch /var/lib/cloud/instance/locale-check.skip
fi

# UPDATE
if [[ "$1" == "update" ]]; then
    cd /opt/envpilot-cli && sudo git pull
fi

# INSTALL
if [[ "$1" == "install" ]]; then
    installWrapper $2
fi

# UNINSTALL
if [[ "$1" == "uninstall" ]]; then
    uninstallWrapper $2
fi

# CONFIGURE
if [[ "$1" == "config" ]]; then
    if [[ "$2" == "apps" ]]; then
        response "configuring apps..."

        IFS=' ' ; for i in `echo $apps`; do
            response "$i configuration"
            chmod +x /vagrant/config/apps/$i/config.sh
            /vagrant/config/apps/$i/config.sh
        done
    fi

    if [[ "$2" == "database" ]]; then
	source <(grep = /vagrant/config/mysql.ini | sed 's/ *= */=/g')

	response "creating $database database..."

        Q2="CREATE DATABASE $database;"
        Q3="GRANT ALL ON $database.* TO '$user'@'localhost';"
        Q4="FLUSH PRIVILEGES;"

        SQL="${Q2}${Q3}${Q4}"

        echo "$SQL" | mysql -u root -ptoor
        response "done creating $database database..."
    fi
fi

# DELETE DATABASE
if [[ "$1" == "rm" ]]; then
    if [[ "$2" == "database" ]]; then
        source <(grep = /vagrant/config/mysql.ini | sed 's/ *= */=/g')

	    response "deleting $database database..."

        Q2="DROP DATABASE $database;"
        SQL="${Q2}"

        echo "$SQL" | mysql -u root -ptoor
        response "done deleting $database database..."
    fi
fi

# VHOSTS
if [[ "$1" == "vhosts" ]]; then
    if [[ "$2" == "update" ]]; then
        IFS=' ' ; for i in `echo $apps`; do
            response "$i vhost setup"

            if [[ -e "/etc/nginx/sites-available/$i" ]]; then
                sudo rm /etc/nginx/sites-available/$i
                sudo rm /etc/nginx/sites-enabled/$i
            fi

            sudo cp /vagrant/config/apps/$i/vhost /etc/nginx/sites-available/$i
            sudo ln -s /etc/nginx/sites-available/$i /etc/nginx/sites-enabled/$i
        done

        response "restarting nginx..."
        sudo service nginx restart
    fi
fi
