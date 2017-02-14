# PostgreSQL HA

This repository maintain a code needed to run PostgreSQL cluster in streaming replication mode with PgPool inside a Docker containers.
It utilize Docker Swarm, but it can be run on a single host, ie. for testing purposes.
It solves automatic and manual failover and manual recovery and failback. It uses constraints and labels to ensure proper containers scheduling.

> At the moment this solution uses `restart: none` policy to avoid starting failed container during Swarm node startup. It requires external governor like `systemd`.

#### Prerequisites:

- HA mode
  - Docker Compose 1.9.0
  - Docker Machine 0.8.2
  - Docker Swarm 1.2.6


- Single host:
  - Docker 1.13.0
  - Docker Compose 1.9.0

#### Architecture

#### Command line reference

The following list of commands is available for the `./bin/db_ctl.sh` script.

| Command   | Parameters | Description |
|---------|---------------|-------|
| `build` |  | Builds and distributes `postgres-cluster` image. |
| `init` | `[-f]` | Initializes data directories, creates networks and configures streaming replication. `-f` flag is required to move any existing configuration and data files. |
| `start` |  | Starts containers. |
| `stop` |   |  Stops containers. |
| `status` |  | Shows current cluster status. |
| `failover` |  | Failover gracefully. |
| `recovery` | `[-f]` | Recovers failed node. `-f` flag is required to perform `full recovery` an to move any existing configuration and data files. |
| `failback` |  | Failback gracefully. |
| `user create` | `<username> <password>` | Creates user account. |
| `user delete` | `<username>` | Deletes user account. |
| `user password` | `<username> <password>` | Updates the user's password.  |

#### Configuration

For the configuration `etc/env.sh` file is used by default.
This can be override using `-f` flag, ie. `./bin/db_ctl.sh -f etc/env.prod.sh`

| Variable | Default value | Description  |
|---------------|----------|---|
| `POSTGRES_USER` | `postgres` | Postgres user name. |
| `POSTGRES_PASSWORD` | `secret` | Postgres user password. |
| `PGPORT` | `5433` | PostgreSQL database port. |
| `PGPOOL_PORT` | `5432` | PgPool database port. |
| `PGPOOL_ALIAS` | `db` | PgPool network alias. |
| `REPLICATION_USER` | `replication` | PostgreSQL replication user's name. |
| `REPLICATION_PASSWORD` | `secret` | PostgreSQL replication user's password. |
| `PGDATA` | `/var/lib/postgresql/data` | PostgreSQL data directory inside a container. |
| `CLUSTER_ARCHIVE` | `/var/lib/postgresql/archive` | PostgreSQL archive logs directory inside a container. |
| `PCP_USER` | `postgres` |  PgPool administrator user' name. |
| `PCP_PASSWORD` | `secret` | PgPool administrator user's password. |
| `MASTER_NODE` | `node-0` | Docker host's name for `master` node used in `docker-machine`. |
| `STANDBY_NODE` | `node-1` | Docker host's name for `standby` node used in `docker-machine`.  |
| `MASTER_IP` | `10.0.0.11` | IP address of the `master` node used in the `backend` network. |
| `STANDBY_IP` | `10.0.0.12` | IP address of the `standby` node used in the `backend` network. |
| `POSTGRES_BACKEND_SUBNET` | `10.0.0.0/24` | Subnet of the `backend` network. |
| `POSTGRES_FRONTEND_SUBNET` | `10.0.1.0/24` | Subnet of the `frontend` network. |
| `COMPOSE_PROJECT_NAME` | `postgres-cluster` | Used as a naming prefix for containers and networks. Useful for multi tenancy. |
| `COMPOSE_HTTP_TIMEOUT` | `300` | Docker API timeout. |
| `DOCKER_HUB_IMAGE` | `true` | Use Docker HUB image. |
| `DOCKER_HUB_IMAGE_VERSION` | `latest` | Version tag for Docker HUB image. |
| `DOCKER_REGISTRY_HOST` | `192.168.56.10` | Docker Registry address. Not used in single mode. |
| `DOCKER_REGISTRY_PORT` | `5000` | Docker Registry port. Not used in single mode. |
| `MASTER_VOLUME_ETC_PGPOOL` | `/data/docker/postgres-cluster/master/etc/pgpool2` | PgPool configuration directory on `master` node. |
| `MASTER_VOLUME_ETC_SSH` | `/data/docker/postgres-cluster/master/etc/ssh` | SSH server configuration directory on `master` node. |
| `MASTER_VOLUME_ROOT_SSH` | `/data/docker/postgres-cluster/master/root/ssh` | SSH configuration directory for `root` user on `master` node. |
| `MASTER_VOLUME_POSTGRES_SSH` | `/data/docker/postgres-cluster/master/postgresql/ssh` | SSH configuration directory for `postgres` user on `master` node. |
| `MASTER_VOLUME_POSTGRES_ARCHIVE` | `/data/docker/postgres-cluster/master/postgresql/archive` | PostgreSQL archive logs directory on `master` node. |
| `MASTER_VOLUME_POSTGRES_DATA` | `/data/docker/postgres-cluster/master/postgresql/data` | PostgreSQL data directory on `master` node. |
| `STANDBY_VOLUME_ETC_PGPOOL` | `/data/docker/postgres-cluster/standby/etc/pgpool2` |  PgPool configuration directory on `standby` node. |
| `STANDBY_VOLUME_ETC_SSH` | `/data/docker/postgres-cluster/standby/etc/ssh` | SSH server configuration directory on `standby` node. |
| `STANDBY_VOLUME_ROOT_SSH` | `/data/docker/postgres-cluster/standby/root/ssh` | SSH configuration directory for `root` user on `standby` node. |
| `STANDBY_VOLUME_POSTGRES_SSH` | `/data/docker/postgres-cluster/standby/postgresql/ssh` | SSH configuration directory for `postgres` user on `standby` node. |
| `STANDBY_VOLUME_POSTGRES_ARCHIVE` | `/data/docker/postgres-cluster/standby/postgresql/archive` | PostgreSQL data directory on `standby` node. |
| `STANDBY_VOLUME_POSTGRES_DATA` | `/data/docker/postgres-cluster/standby/postgresql/data` | PostgreSQL data directory on `standby` node. |
| `DEBUG` | `0` | Enables `-x` flag for `bash` debugging. |

#### Examples

#### Notes

#### TODO
