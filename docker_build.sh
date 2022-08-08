#!/bin/bash

# docker run --user 1000:1000 --name glpi_mysql -v ${PWD}/mysql:/var/lib/mysql -p 33060:3306 -e MYSQL_ROOT_PASSWORD=glpi123 -d mysql:5.7 

docker build -t unisuam/glpi:php80 .

# docker build --build-arg environment=development -t unisuam/glpi:php80 .

docker run -dit -v ${PWD}/glpi:/var/www --name unisuam_glpi --link glpi_mysql -p 8080:80 unisuam/glpi:php80
