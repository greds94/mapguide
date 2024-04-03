#!/bin/bash
# Note: I've written this using sh so it works in the busybox container too
set -e

export PATH=${MG_PATH}/server/bin:$PATH
export MENTOR_DICTIONARY_PATH=${MG_PATH}/share/gis/coordsys
export LD_LIBRARY_PATH=/usr/local/fdo-${FDOVER_MAJOR_MINOR_REV}/lib64:${MG_PATH}/webserverextensions/lib64:${MG_PATH}/lib64:${MG_PATH}/server/lib64:$LD_LIBRARY_PATH
export NLSPATH=/usr/local/fdo-${FDOVER_MAJOR_MINOR_REV}/nls/%N:"$NLSPATH"
mkdir -p /var/lock/mgserver
ln -sf ${MG_PATH}/server/bin/mapguidectl /usr/local/bin/mapguidectl

SLEEPTIME=1
NO_APACHE=0
NO_TOMCAT=0
RESET_PASSWORD=0
NO_SETUP_LOG_LINK=0
MG_PIDFILE=/var/run/mapguide.pid

start_apache(){
  echo "Starting Apache..."
  cd ${MG_PATH}/webserverextensions/apache2/bin
  ./apachectl start
}

start_tomcat(){
  echo "Starting tomcat..."
  cd ${MG_PATH}/webserverextensions/tomcat/bin
  ./startup.sh
}

start_mg(){
  echo "Starting mgserver..."
  ${MG_PATH}/server/bin/mapguidectl start
  $MG_PATH/server/bin/mapguidectl status | perl -pe 's/\D//g' | tee $MG_PIDFILE
}

setup_admin_password() {
  cd ${MG_PATH}/server/bin
  ./mgserver setpwd ${ADMIN_USER} ${ADMIN_PASSWORD}
}

#SETUP LINK FOR LOG
setup_log_link() {
  for log_file in Access Admin Authentication; do
    ln -sf /dev/stdout "${MGLOG_PATH}/${log_file}.log"
  done
  ln -sf /dev/stderr ${MGLOG_PATH}/Error.log
  ln -sf /dev/stdout ${MGAPACHE_LOG}/access_log &
  ln -sf /dev/stdout ${MGAPACHE_LOG}/mod_jk.log
  ln -sf /dev/stderr ${MGAPACHE_LOG}/error_log
}

stop_all(){
  if [ $NO_APACHE -eq 0 ]; then
    echo "Stopping Apache server..."
    cd ${MG_PATH}/webserverextensions/apache2/bin
    ./apachectl stop
  fi

  if [ $NO_TOMCAT -eq 0 ]; then
    echo "Stopping Tomcat server..."
    cd ${MG_PATH}/webserverextensions/tomcat/bin
    ./shutdown.sh
  fi

  echo "Stopping Mapguide server..."
  cd ${MG_PATH}/server/bin
  ./mapguidectl stop
}

print_help() {
  echo "Help: "
  echo ""
  echo "--stop-all\t\tstop all the service"
  echo "--only-mapguide\t\tstart only mapguide server"
  echo "--no-apache\t\tdon't start apache server"
  echo "--no-tomcat\t\tdon't start tomcat server"
  echo "--reset-password\t\treset admin password"
  echo "--no-setup-log-link\t\tdon't setup link for log files"
  echo "--crash-time\t1\tSeconds to sleep before restart, after crash"
  echo "--help show this help"
}

while test $# -gt 0; do
  case "$1" in
    -h|--help)
     print_help
      exit 0
    ;;
    --only-mapguide)
      shift
      NO_APACHE=1
      NO_TOMCAT=1
    ;;
    --no-apache)
      shift
      NO_APACHE=1
    ;;
    --no-tomcat)
      shift
      NO_TOMCAT=1
    ;;
    --reset-password)
      shift
      RESET_PASSWORD=1
    ;;
    --no-setup-log-link)
      shift
      NO_SETUP_LOG_LINK=1
    ;;
    --crash-time)
      shift
      if ! [ $1 =~'^[0-9]+$' ];then
        echo "error: the --crash-time must be any number">&2;
        exit 1;
      fi
      SLEEPTIME=$1
    ;;
    *)
      echo "Invalid option please use as bellow"
      echo "$package --help"
      exit 2
      break
    ;;
  esac
done

trap stop_all SIGINT SIGTERM

start_mg

if [ $RESET_PASSWORD -eq 1 ]; then
  setup_admin_password
fi

if [ $NO_SETUP_LOG_LINK -eq 0 ]; then
  setup_log_link
fi

if [ $NO_APACHE -eq 0 ]; then
  start_apache
fi

if [ $NO_TOMCAT -eq 0 ]; then
  start_tomcat
fi

while true; do
  sleep $SLEEPTIME
  pid=$(cat ${MG_PIDFILE})
  if [ ! -e /proc/$pid -a /proc/$pid/exe ]; then
    echo "Mapguide was stopped unexpectedly and will be restarting..."
    start_mg
  fi
done
