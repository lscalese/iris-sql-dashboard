## iris-sql-dashboard

This project is designed to provide an API for collecting and analyzing statistics of SQL queries executed in an IRIS database. It uses Docker to facilitate the deployment and execution of the application. The main features include collecting execution statistics of SQL queries, such as the number of executions, average execution time, and other relevant metrics. These statistics can then be visualized and analyzed using Grafana dashboards.

**Note**: article with all details soon available on community.intersystems.com


## Prerequisites

Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.

## Installation 

### Docker

docker-compose up influxdb2

Clone/git pull the repo into any local directory

```
git clone https://github.com/lscalese/iris-sql-dashboard.git
```

### Environment Configuration

Before starting the application, you need to configure the environment variables. Follow these steps:

1. Copy the `.env.example` file to `.env`:

```sh
cp .env.example .env
```

2. Edit the .env file to set your own values for the environment variables. Here are the variables you need to configure:

**TZ**: Set your timezone. You can find the complete list of timezones here.

Example: TZ=Europe/Paris

**DOCKER_INFLUXDB_INIT_PASSWORD**: Set the password for the InfluxDB admin user.

Example: DOCKER_INFLUXDB_INIT_PASSWORD=sysadmin

**IRIS_USER**:  Set the IRIS login username used by the Telegraf agent to request the web application `/csp/sqlstats/api`.

Example: IRIS_USER=_SYSTEM  

**IRIS_PASSWORD**: Set the IRIS login password used by the Telegraf agent to request the web application `/csp/sqlstats/api/`.

Example: IRIS_PASSWORD=SYS

3. Start InfluxDB for the first time to generate the API keys. This step is only necessary the first time you set up the application. The .env file will be updated with the generated API keys.

```bash
docker compose up -d influxdb2
```

4. Start all containers

```bash
docker compose up -d
```

### IRIS backend using zpm

```
zpm "install sql-stats-api"
```

### IRIS backend without zpm

If you can't use zpm, import and compile `export.xml` and then execute the Init() method to setup iris requirement.  

```objectscript
Do $SYSTEM.OBJ.Load("<git-directory>/iris-sql-dashboard/export.xml", "ck")
Do ##class(dc.sqlstats.services.Install).Init()
```

Or if the machine can access to internet

```objectscript
set ns=$namespace,$namespace="%SYS" do ##class(Security.SSLConfigs).Create("ssl") set $namespace=ns,r=##class(%Net.HttpRequest).%New(),r.Server="raw.githubusercontent.com",r.SSLConfiguration="ssl" do r.Get("/lscalese/iris-sql-dashboard/refs/heads/master/export.xml"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c"),##class(dc.sqlstats.services.Install).Init()
```