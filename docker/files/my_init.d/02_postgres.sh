#!/bin/bash -e

if [ "$DEBUG" = "1" ]; then
  set -x
fi

function wait_for_db() {
  TIMEOUT=5
  MAX_TRIES=10
  while [[ "$MAX_TRIES" != "0" ]]; do
    if [ "$1" != "" ]; then
      EXISTS=$(psql -h $1 -U $POSTGRES_USER -w -tnAc "SELECT 1" postgres || true)
      if [[ "${EXISTS:-1}" != "1" ]]; then
        sleep $TIMEOUT
      else
        break
      fi
    else
      MASTER_EXISTS=$(psql -h master -U $POSTGRES_USER -w -tnAc "SELECT 1" postgres || true)
      STANDBY_EXISTS=$(psql -h standby -U $POSTGRES_USER -tnAc "SELECT 1" postgres || true)
      if [[ "$MASTER_EXISTS" != "1" || "$STANDBY_EXISTS" != "1" ]]; then
        sleep $TIMEOUT
      else
        break
      fi
    fi
    MAX_TRIES=`expr "$MAX_TRIES" - 1`
  done
}

function pgpool_start() {

  # sed -ri "s/^#?(ssl)\s*=\s*.*/\1 = 'on'/" /etc/pgpool2/pgpool.conf
  # sed -ri "s/^#?(ssl_key)\s*=\s*.*/\1 = ''/" /etc/pgpool2/pgpool.conf
  # sed -ri "s/^#?(ssl_cert)\s*=\s*.*/\1 = ''/" /etc/pgpool2/pgpool.conf
  # sed -ri "s/^#?(ssl_ca_cert)\s*=\s*.*/\1 = ''/" /etc/pgpool2/pgpool.conf

  sed -ri "s/^#?(sr_check_user)\s*=\s*.*/\1 = '$POSTGRES_USER'/" /etc/pgpool2/pgpool.conf
  sed -ri "s/^#?(sr_check_password)\s*=\s*.*/\1 = '$POSTGRES_PASSWORD'/" /etc/pgpool2/pgpool.conf
  sed -ri "s/^#?(health_check_user)\s*=\s*.*/\1 = '$POSTGRES_USER'/" /etc/pgpool2/pgpool.conf
  sed -ri "s/^#?(health_check_password)\s*=\s*.*/\1 = '$POSTGRES_PASSWORD'/" /etc/pgpool2/pgpool.conf

  ln -sf /var/run/postgresql/.s.PGSQL.9898 /tmp/.s.PGSQL.9898

  wait_for_db || true
  gosu postgres pgpool -n
}

if [ ! -d $CLUSTER_ARCHIVE ]; then
    mkdir -m 0700 -p $CLUSTER_ARCHIVE
    chown postgres:postgres $CLUSTER_ARCHIVE
fi

if [ ! -d $PGDATA ]; then
    mkdir -m 0700 -p $PGDATA
    chown postgres:postgres $PGDATA
fi

rm -f /var/run/postgresql/.s*

echo $PCP_USER:$(echo -n $PCP_PASSWORD | md5sum | awk '{ print $1 }') > /etc/pgpool2/pcp.conf
echo "*:*:$PCP_USER:$PCP_PASSWORD" > /var/lib/postgresql/.pcppass
chmod 600 /var/lib/postgresql/.pcppass
chown postgres:postgres /var/lib/postgresql/.pcppass
[ -d /var/log/pgpool/oiddir ] || (mkdir -p /var/log/pgpool/oiddir && chown postgres:postgres /var/log/pgpool/oiddir)

echo "*:*:*:$POSTGRES_USER:$POSTGRES_PASSWORD" > ~/.pgpass
chmod 600 ~/.pgpass

case $IMAGE_TYPE in
  master)
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      chmod 0700 $PGDATA
      chmod 0700 $CLUSTER_ARCHIVE
      chown postgres:postgres $PGDATA
      chown postgres:postgres $CLUSTER_ARCHIVE

      gosu postgres initdb -D $PGDATA
      gosu postgres pg_ctl -D $PGDATA -w start
      gosu postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD '$POSTGRES_PASSWORD';" postgres
      gosu postgres psql -c "CREATE USER $REPLICATION_USER WITH LOGIN REPLICATION CONNECTION LIMIT 10 ENCRYPTED PASSWORD '$REPLICATION_PASSWORD';" postgres
      gosu postgres pg_ctl -D $PGDATA -m fast -w stop

      echo "wal_level = hot_standby" >> $PGDATA/postgresql.conf
      echo "archive_command = 'gzip -c %p > $CLUSTER_ARCHIVE/%f.gz && scp $CLUSTER_ARCHIVE/%f.gz standby:$CLUSTER_ARCHIVE/'" >> $PGDATA/postgresql.conf
      echo "archive_mode = on" >> $PGDATA/postgresql.conf
      echo "wal_log_hints = on" >> $PGDATA/postgresql.conf
      echo "max_wal_senders = 3" >> $PGDATA/postgresql.conf
      grep -Ec "^port = $PGPORT" $PGDATA/postgresql.conf > /dev/null || echo "port = $PGPORT" >> $PGDATA/postgresql.conf
      sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" $PGDATA/postgresql.conf


      echo "host all all 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf
      echo "host replication $REPLICATION_USER 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf

      rm -f /tmp/postgresql_failover_trigger_file_0
      gosu postgres pg_ctl -D $PGDATA -w start
      pgpool_start
    else
      rm -f /tmp/postgresql_failover_trigger_file_0
      gosu postgres pg_ctl -D $PGDATA -w start
      pgpool_start
    fi
  ;;

  standby)
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      sleep 15
      MAX_TRIES=50
      while [[ "$MAX_TRIES" != "0" ]]; do
        DB_EXISTS=`PGPASSWORD=$POSTGRES_PASSWORD psql --username $POSTGRES_USER -h master -p $PGPORT -tAc "SELECT 1" postgres`
        if [[ "$DB_EXISTS" != "1" ]]; then
          sleep 5
        else
          break
        fi
        MAX_TRIES=`expr "$MAX_TRIES" - 1`
      done

      chmod 0700 $PGDATA
      chmod 0700 $CLUSTER_ARCHIVE
      chown postgres:postgres $PGDATA
      chown postgres:postgres $CLUSTER_ARCHIVE

      rsync -avz master:$CLUSTER_ARCHIVE/ $CLUSTER_ARCHIVE/
      gosu postgres pg_basebackup -D $PGDATA -w -X stream -d "host=master port=$PGPORT user=$REPLICATION_USER password=$REPLICATION_PASSWORD"

      echo "standby_mode = on" >> $PGDATA/recovery.conf
    	echo "primary_conninfo = 'host=master port=$PGPORT user=$REPLICATION_USER password=$REPLICATION_PASSWORD'" >> $PGDATA/recovery.conf
    	echo "restore_command = 'gzip -dc $CLUSTER_ARCHIVE/%f.gz > %p'" >> $PGDATA/recovery.conf
      echo "recovery_target_timeline = 'latest'" >> $PGDATA/recovery.conf
      echo "trigger_file = '/tmp/postgresql_failover_trigger_file_0'" >> $PGDATA/recovery.conf
    	chown postgres:postgres  $PGDATA/recovery.conf

      echo "hot_standby = on" >> $PGDATA/postgresql.conf
      grep -Ec "^port = $PGPORT" $PGDATA/postgresql.conf > /dev/null || echo "port = $PGPORT" >> $PGDATA/postgresql.conf
      sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" $PGDATA/postgresql.conf

      echo "host all all 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf
      echo "host replication $REPLICATION_USER 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf

      rm -f /tmp/postgresql_failover_trigger_file_0
      gosu postgres pg_ctl -D $PGDATA -w start
      pgpool_start
    else
      rm -f /tmp/postgresql_failover_trigger_file_0
      gosu postgres pg_ctl -D $PGDATA -w start
      pgpool_start
    fi
  ;;

  *)
    echo "IMAGE_TYPE=$IMAGE_TYPE not available!"
    exit 1
  ;;
esac
