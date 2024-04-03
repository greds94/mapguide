FROM ubuntu:16.04

ENV TEMPDIR=/tmp/install_mapguide
ENV FDOVER_MAJOR_MINOR_REV=4.2.0
ENV MGVER_MAJOR_MINOR_REV=4.0.0
ENV MG_PATH=/usr/local/mapguideopensource-${MGVER_MAJOR_MINOR_REV}
ENV MGLOG_PATH=${MG_PATH}/server/Logs
ENV MGAPACHE_LOG=${MG_PATH}/webserverextensions/apache2/logs
ENV MGTOMCAT_LOG=${MG_PATH}/webserverextensions/tomcat/logs
ENV ADMIN_USER=Administrator
ENV ADMIN_PASSWORD=admin

WORKDIR ${TEMPDIR}

COPY utilities/ .
RUN chmod +x mapguideopensource-4.0.0.9740-ubuntu16-install.run && apt-get update \
    && ./mapguideopensource-4.0.0.9740-ubuntu16-install.run --noexec --nox11 --target . && apt-get update \
    && ./install-with-rdbms.sh --headless --with-rdbms --no-service-install --no-mgserver-start \
    --no-tomcat-start --no-httpd-start --with-sdf --with-shp --with-sqlite --with-gdal \
    --with-ogr --with-wfs \
    && apt-get install unzip -y \ 
    && mkdir /usr/share/fonts/truetype/msttcorefonts && unzip msttcorefonts.zip -d /usr/share/fonts/truetype/msttcorefonts \
    && apt-get remove unzip -y

WORKDIR ${MG_PATH}

# SETTING UP PERMISSION
RUN chmod 777 webserverextensions/www/TempDir
RUN chmod a+rw ${MG_PATH}/webserverextensions/www/fusion/lib/tcpdf/cache/

#REMOVE TEMP FILES
RUN rm -rf ${TEMPDIR}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8008 2810 2811 2812 8080 8000

ENTRYPOINT ["/entrypoint.sh"]