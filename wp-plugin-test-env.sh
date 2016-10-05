#!/usr/bin/sh

# execute this from within the plugin directory
# requires docker, curl

cwd=$(pwd)
cwd_name=$(basename $(pwd))

port=8880

wp_user="admin"
wp_pass="pass"
wp_email="example@example.com"

printf "starting docker containers..."
docker run -d \
    --name db-test-$cwd_name \
    -e MYSQL_ROOT_PASSWORD='root' \
    mysql >/dev/null 2>&1 \
    && printf "." \
    || printf "\nmysql already up!"
docker run -d \
    --name wp-plugin-test-$cwd_name \
    --link db-test-$cwd_name:mysql \
    -p 127.0.0.1:$port:80 \
    -v $(pwd):/var/www/html/wp-content/plugins/$cwd_name \
    ak05/wordpress-test >/dev/null 2>&1 \
    && printf "." \
    || printf "\nwp container already up!"
echo ' done!'

printf "waiting for apache..."
until $(curl -LNs 127.0.0.1:$port | grep -qi '<html') ; do
    printf "."
    sleep 1
done
echo ' done!'

dockerid=$(docker ps -aqf "name=wp-plugin-test-$cwd_name")
printf 'installing wordpress...'
docker exec -d $dockerid wp --allow-root core install \
    --url="localhost:$port" \
    --title="Testing $cwd_name" \
    --admin_user="$wp_user" \
    --admin_password="$wp_pass" \
    --admin_email="$wp_email"
echo ' done!'

printf 'installing plugin...'
sleep 2 # belows fails if sleep omitted for some reason
docker exec -d $dockerid wp --allow-root plugin activate $cwd_name
echo  ' done!'
echo
echo wordpress listening on localhost:$port
echo username: $wp_user \| password: $wp_pass
echo
echo get a bash shell on the container by running:
echo docker exec -it $dockerid /bin/bash
