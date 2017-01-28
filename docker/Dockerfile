# vim:set ft=dockerfile:
FROM phusion/baseimage:latest

ENV PG_MAJOR 9.6

ENV CLUSTER_ARCHIVE /var/lib/postgresql/archive

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH

ENV PGDATA /var/lib/postgresql/data

RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 -d /var/lib/postgresql -s /bin/bash postgres

RUN usermod -p '*' postgres

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main $PG_MAJOR" > /etc/apt/sources.list.d/pgdg.list

RUN curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -qqy gosu iputils-ping net-tools pgpool2 postgresql rsync

RUN rm -rf /var/lib/postgresql/$PG_MAJOR

ADD files/my_init.d/01_sshd.sh /etc/my_init.d/

ADD files/my_init.d/02_postgres.sh /etc/my_init.d/

RUN chmod +x /etc/my_init.d/*.sh

ADD files/ha/failover.sh /usr/local/lib/ha/

RUN chmod +x /usr/local/lib/ha/*.sh

ADD files/pgpool2/pgpool.conf /etc/pgpool2/

ADD files/pgpool2/pool_hba.conf /etc/pgpool2/

ADD files/pgpool2/pool_passwd /etc/pgpool2/

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME ["/var/lib/postgresql/archive", "/var/lib/postgresql/data"]

EXPOSE 5432 9898
