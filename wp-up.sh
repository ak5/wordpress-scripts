#!/usr/bin/sh
set -e

# sets up a WordPress development environment in Docker for the current dir

# requires docker, curl

# WordPress Configuration

wp_user="admin"
wp_pass="pass"
wp_email="example@example.com"

## That's all, stop editing! Happy developing. ##

cwd=$(pwd)
cwd_name=$(basename $(pwd))

db_container="wp-db-$cwd_name"
wp_container="wp-$cwd_name"

if [ -z "$1" ]; then
  mount_target="/opt/$cwd_name"
  post_setup(){
    :
  }
  message(){
    echo -e "\tThis directory is mounted in /opt/$cwd_name"
  }
fi

# TODO instead of passing args detect what the user wants - it's WordPress

if [ "$1" = "plugin" ]; then
  name=$cwd_name; # TODO detect from index.php plugin.php ${cwd_name}.php etc
  mount_target="/var/www/html/wp-content/plugins/$name"
  post_setup(){
    docker exec -d $wp_container wp --allow-root plugin activate $cwd_name
  }
  message(){
    echo -e "\tThe $name plugin was installed and activated"
  }
fi

if [ "$1" = "theme" ]; then
  name=$cwd_name; # TODO detect from functions.php
  mount_target="/var/www/html/wp-content/themes/$name"
  post_setup(){
    docker exec -d $wp_container wp --allow-root theme activate $cwd_name
  }
  message(){
    echo -e "\tThe $name theme was installed and activated"
  }
fi

# TODO better ascii art

echo
echo -e "\t###################################################"
echo -e "\t#                                                 #"
echo -e "\t#    Fixing up that nice dev env in docker ...    #"
echo -e "\t#                                                 #"
echo -e "\t###################################################"
echo
echo

# TODO persist database to hidden folder
docker run -d \
  --name $db_container \
  -e MYSQL_ROOT_PASSWORD='root' \
  --restart unless-stopped \
  mariadb >/dev/null # 2>&1

# TODO persist uploads/media to hidden folder
docker run -d \
  --name $wp_container \
  -p 127.0.0.1::80 \
  --link $db_container:mysql \
  --restart unless-stopped \
  -v $(pwd):$mount_target \
  ak05/wordpress-test >/dev/null # 2>&1

port=$(docker ps --filter name=$wp_container --format="{{.Ports}}" \
  | sed 's/127\.0\.0\.1:\([0-9]\+\).*$/\1/')

# wait until environment is launched
until $(curl -LNs 127.0.0.1:$port | grep -qi '<html') ; do
  sleep 1
done

docker exec -d $wp_container wp --allow-root core install \
  --url="localhost:$port" \
  --title="Testing $cwd_name" \
  --admin_user="$wp_user" \
  --admin_password="$wp_pass" \
  --admin_email="$wp_email"

post_setup

echo -e "\tWordPress running on http://localhost:$port"
echo
message
echo
echo -e "\tAdministrator Credentials:"
echo
echo -e "\tusername: $wp_user"
echo -e "\tpassword: $wp_pass"
echo
echo
echo -e "\tget a bash shell on the container by running:"
echo
echo -e "\tdocker exec -it $wp_container bash"
echo
