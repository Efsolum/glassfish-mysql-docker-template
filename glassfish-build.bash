#!/usr/bin/env bash
set -e

PROJECT_NAME=${PROJECT_NAME:-'project'}

ALPINE_VERSION=${ALPINE_VERSION:-'3.4'}

JAVA_MINOR_VERSION=${JAVA_MINOR_VERSION:-'8'}
JAVA_VERSION=${JAVA_VERSION:-"1.${JAVA_MINOR_VERSION}"}

MAVEN_MAJOR_VERSION=${MAVEN_MAJOR_VERSION:-'3'}
MAVEN_VERSION=${MAVEN_VERSION:-"${MAVEN_MAJOR_VERSION}.3.3"}

GLASSHFISH_MAJOR_VERSION=${GLASSHFISH_MAJOR_VERSION:-'4'}
GLASSHFISH_VERSION=${GLASSHFISH_VERSION:-"${GLASSHFISH_MAJOR_VERSION}.1"}

CONTAINER_USER=${CONTAINER_USER:-developer}
TEMP_DIR=$(mktemp --directory rails-build-XXXXXXXX)

docker_end() {
		exit=$?

		echo 'Cleaning up'
		rm -r $TEMP_DIR

		exit $exit;
}

trap docker_end EXIT SIGINT SIGTERM

cat <<EOF > $TEMP_DIR/Dockerfile
FROM alpine:${ALPINE_VERSION}
MAINTAINER 'Matthew Jordan <matthewjordandevops@yandex.com>'

ENV LANG en_US.UTF-8
ENV SSL_CERT_DIR /etc/ssl/certs
ENV JAVA_HOME /usr/lib/jvm/java-1.${JAVA_MINOR_VERSION}-openjdk
ENV MAVEN_HOME /usr/local/maven-${MAVEN_VERSION}
ENV GLASSFISH_HOME /usr/local/glassfish-${GLASSHFISH_VERSION}
ENV PATH "\${MAVEN_HOME}/bin:\${GLASSFISH_HOME}/bin:\${JAVA_HOME}/bin:\$PATH"

RUN adduser -u $(id -u $USER) -Ds /bin/bash $CONTAINER_USER

RUN apk update
RUN apk add \
				bash \
				expect \
				ca-certificates \
				git \
				openjdk${JAVA_MINOR_VERSION} \
				openjdk${JAVA_MINOR_VERSION}-jre \
				openssl \
				sudo \
				wget \
		&& echo 'End of package(s) installation.' \
		&& rm -rf '/var/cache/apk/*'

RUN which java && java -version

COPY glassfish-build.bash /usr/local/bin/glassfish-build.bash
RUN chmod u+x /usr/local/bin/glassfish-build.bash
RUN glassfish-build.bash
RUN chown -R ${CONTAINER_USER}:${CONTAINER_USER} \${GLASSFISH_HOME}

COPY change-admin-password.sh /usr/local/bin/change-admin-password.sh
RUN chmod ugo+x /usr/local/bin/change-admin-password.sh

COPY maven-build.bash /usr/local/bin/maven-build.bash
RUN chmod u+x /usr/local/bin/maven-build.bash
RUN maven-build.bash
RUN chown -R ${CONTAINER_USER}:${CONTAINER_USER} \${MAVEN_HOME}

USER $CONTAINER_USER
WORKDIR /var/www/projects

VOLUME ["/var/www/projects"]
# 4848 (administration), 8080 (HTTP listener), 8181 (HTTPS listener), 9009 (JPDA debug port)
EXPOSE 4848 8080 8181 9009
CMD sh -c 'kill -STOP \$$'
EOF

cat <<EOF >> $TEMP_DIR/change-admin-password.sh
#!/usr/bin/expect

set password [lindex $argv 0]

spawn asadmin --user admin change-admin-password
expect "password"
send "\n"
expect "password"
send "$password\n"
expect "password"
send "$password\n"
expect eof
exit
EOF

cat <<EOF >> $TEMP_DIR/maven-build.bash
#!/usr/bin/env bash
set -eo pipefail

mkdir -v /tmp/maven-build
cd /tmp/maven-build

wget "http://apache.osuosl.org/maven/maven-${MAVEN_MAJOR_VERSION}/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"

tar -xvf apache-maven-${MAVEN_VERSION}-bin.tar.gz
mv apache-maven-${MAVEN_VERSION} \${MAVEN_HOME}

rm -rv /tmp/maven-build

cd /
which mvn
mvn --version
EOF

cat <<EOF >> $TEMP_DIR/glassfish-build.bash
#!/usr/bin/env bash
set -eo pipefail

mkdir -v /tmp/glassfish-build
cd /tmp/glassfish-build

wget "http://download.java.net/glassfish/${GLASSHFISH_VERSION}/release/glassfish-${GLASSHFISH_VERSION}.zip"
unzip glassfish-4.1.zip

mv glassfish${GLASSHFISH_MAJOR_VERSION} \${GLASSFISH_HOME}
cd /
rm -vr /tmp/glassfish-build

chmod +x \${GLASSFISH_HOME}/bin/*
EOF

docker build \
			 --tag "${PROJECT_NAME}/glassfish-${JAVA_VERSION}-${GLASSHFISH_VERSION}:latest" \
			 $TEMP_DIR
docker tag \
			 "${PROJECT_NAME}/glassfish-${JAVA_VERSION}-${GLASSHFISH_VERSION}:latest" \
			 "${PROJECT_NAME}/glassfish-${JAVA_VERSION}-${GLASSHFISH_VERSION}:$(date +%s)"
