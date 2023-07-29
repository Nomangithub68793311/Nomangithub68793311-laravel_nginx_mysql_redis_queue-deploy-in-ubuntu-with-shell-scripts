#! /bin/bash
 ####################

# author : Rana Ahamed
# date : 24/08/2023
# using php ,composer, mysql,supervisor
# trying to deploy a laravel app in ubuntu through shell scripting
# plz read the README.md file to understand the file

###################
# declaring parameters
set -x
set -e 
set -o pipefail

###installing php and all dependency 
sudo apt-get update
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get install php8.0 php8.0-mbstring php8.0-gettext php8.0-zip php8.0-fpm php8.0-curl php8.0-mysql php8.0-gd php8.0-cgi php8.0-soap php8.0-sqlite3 php8.0-xml php8.0-redis php8.0-bcmath php8.0-imagick php8.0-intl -y


##installing mysql and mysql client
sudo apt-get install mysql-server -y
sudo apt-get install mysql-client -y
sudo apt-get install zip unzip git -y

#installing composer
sudo curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar  /usr/local/bin/composer
sudo chmod +x   /usr/local/bin/composer
# installing nginx
sudo apt-get install nginx -y

#setup database ,user and password
if [ -f /root/.my.cnf ]; then
	echo "Enter database name!"
	read dbname
    
	echo "Creating new MySQL database..."
	mysql -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	echo "Database successfully created!"
	
	echo "Enter database user!"
	read username
    
	echo "Enter the PASSWORD for database user!"
	echo "Note: password will be hidden when typing"
	read -s userpass
    
	echo "Creating new user..."
	mysql -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"

	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -e "FLUSH PRIVILEGES;"
	echo "You're good now :)"
	
	
# If /root/.my.cnf doesn't exist then it'll ask for root password	
else
	echo "Please enter root user MySQL password!"
	echo "Note: password will be hidden when typing"
	read -s rootpasswd
    
	echo "Enter database name!"
	read dbname
    
	echo "Creating new MySQL database..."
	mysql -uroot -p${rootpasswd} -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
	echo "Database successfully created!"
    
	echo "Enter database user!"
	read username
    
	echo "Enter the PASSWORD for database user!"
	echo "Note: password will be hidden when typing"
	read -s userpass
    
	echo "Creating new user..."
	mysql -uroot -p${rootpasswd} -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"
	
	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"
	echo "You're good now :)"
	
fi

#going to website directory and cloning repo and creating necessary parameters for laravel
sudo apt install redis-server -y
echo -e "bind 127.0.0.1" >> /etc/redis/redis.conf
echo -e "supervised systemd" >> /etc/redis/redis.conf
systemctl restart redis-server
systemctl enable redis-server
ss -plnt4
cd /var/www
rm -rf html
echo "enter the right git url : "
read url
repo="$(echo $url | sed -r 's/.+\/([^.]+)(\.git)?/\1/')"
git clone $url
cd $repo
sudo composer update
cp .env.example .env
php artisan key:generate
php artisan jwt:secret

# DB_DATABASE=backend
# DB_USERNAME=root
# DB_PASSWORD=
#edting .env file
# sed -i "s/QUEUE_CONNECTION=sync/QUEUE_CONNECTION=database/g" .env
# sed -i "s/DB_DATABASE=backpage/DB_DATABASE=back4page/g" .env
# sed -i "s/DB_PASSWORD=/DB_PASSWORD=68793311/g" .env
# sed -i "s/DB_USERNAME=root/DB_USERNAME=rana/g" .env
database=$(cat .env.example | grep DB_DATABASE)
sed -i "s/${database}/DB_DATABASE=${dbname}/g" .env
sed -i "s/DB_USERNAME=root/DB_USERNAME=${username}/g" .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=${userpass}/g" .env
sed -i "s/QUEUE_CONNECTION=sync/QUEUE_CONNECTION=database/g" .env
php artisan migrate
cd
#giving permission to that ip can be accessed from browser
sudo chown -R www-data:www-data /var/www/$repo
ip=$(wget -qO- http://ipecho.net/plain | xargs echo)

#setting up nginx server
# sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/mysite

# "server {\nlisten 80;\nlisten [::]:80;\nroot /var/www/$repo/public;\nindex index.php;\nserver_name $ip;\nlocation / {\ntry_files $uri $uri/ /index.php?$query_string;\n}\nlocation ~ \.php$ {\ninclude snippets/fastcgi-php.conf;\nfastcgi_pass unix:/var/run/php/php8.0-fpm.sock;\n}\nlocation ~ /\.ht {\ndeny all;\n}\n}"

echo -e "server {\nlisten 80;\nlisten [::]:80;\nroot /var/www/$repo/public;\nindex index.php;\nserver_name $ip;\nlocation / {\ntry_files $"uri" $"uri"/ /index.php?$"query_string";\n}\nlocation ~ \.php$ {\ninclude snippets/fastcgi-php.conf;\nfastcgi_pass unix:/var/run/php/php8.0-fpm.sock;\n}\nlocation ~ /\.ht {\ndeny all;\n}\n}
" >>  /etc/nginx/sites-available/mysite
sudo ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/
sudo nginx -t
echo "succesfully nginx configured"
sudo chown -R www-data:www-data /var/www/$repo

##setting queue

sudo apt-get install supervisor
# cd /etc/supervisor/conf.d
# config=
#  [program:queue-worker] $'\n'
#  process_name=%(program_name)s_%(process_num)02d 
#  command=php /var/www/back4pagebackend/artisan queue:work 
#  autostart=true  
#  autorestart=true 
#  user=root 
#  numprocs=8 
#  redirect_stderr=true 
#  stdout_logfile=/var/www/back4pagebackend/worker.log 
 

echo -e "[program:queue-worker] \nprocess_name=%(program_name)s_%(process_num)02d \ncommand=php /var/www/$repo/artisan queue:work \nautostart=true\nautorestart=true\nuser=root\nnumprocs=8\nredirect_stderr=true\nstdout_logfile=/var/www/$repo/worker.log
" >>  /etc/supervisor/conf.d/queue-worker.conf
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start queue-worker:*
sudo supervisorctl status
sudo systemctl restart nginx