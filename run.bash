#!/usr/bin/env bash
set -e

PROJECT_NAME=${PROJECT_NAME:-'project'}

JAVA_MINOR_VERSION=${JAVA_MINOR_VERSION:-8}
JAVA_VERSION=${JAVA_VERSION:-"1.${JAVA_MINOR_VERSION}"}
GLASSHFISH_MAJOR_VERSION=${GLASSHFISH_MAJOR_VERSION:-4}
GLASSHFISH_VERSION=${GLASSHFISH_VERSION:-"${GLASSHFISH_MAJOR_VERSION}.1"}
NODE_VERSION=${NODE_VERSION:-'6.2.0'}

DATABASE_USER=${DATABASE_USER:-'app'}
DATABASE_PASS=${DATABASE_PASS:-'password'}

docker_err() {
		exit=$?

		echo '/nStoping containers'
		docker stop mysql-dbms glassfish-web node-assets

		exit $exit;
}

trap docker_err ERR

docker run \
			 --detach=true \
			 --name='mysql-dbms' \
			 --env="DATABASE_USER=${DATABASE_USER}" \
			 --env="DATABASE_PASS=${DATABASE_PASS}" \
			 "${PROJECT_NAME}/mysql-dbms:latest"

docker run \
			 --detach=true \
			 --name='java-dev' \
			 --volume="$(dirname $(pwd))/src:/var/www/projects" \
			 --publish='7070:8080' \
			 "${PROJECT_NAME}/java-${JAVA_VERSION}:latest"

docker run \
			 --detach=true \
			 --name='node-assets' \
			 --volume="$(dirname $(pwd))/src:/var/www/projects" \
			 "${PROJECT_NAME}/node-${NODE_VERSION}:latest"

docker run \
			 --detach=true \
			 --name='glassfish-web' \
			 --publish='8080:8080' \
			 --publish='8181:8181' \
			 --publish='9009:9009' \
			 --publish='4848:4848' \
			 "${PROJECT_NAME}/glassfish-${JAVA_VERSION}-${GLASSHFISH_VERSION}:latest"
