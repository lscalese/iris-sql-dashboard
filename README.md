## iris-sql-dashboard

This project is designed to provide an API for collecting and analyzing statistics of SQL queries executed in an IRIS database. It uses Docker to facilitate the deployment and execution of the application. The main features include collecting execution statistics of SQL queries, such as the number of executions, average execution time, and other relevant metrics. These statistics can then be visualized and analyzed using Grafana dashboards.


## Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.

## Installation 

### Docker

Clone/git pull the repo into any local directory

```
git clone https://github.com/lscalese/iris-sql-dashboard.git
```

Open the terminal in this directory and run:

```
docker compose build
```

3. Run the IRIS container with your project:

```
docker compose up -d
```

### IRIS backend using zpm

```
zpm "install sql-stats-api"
```

### IRIS backend without zpm

If you can't use zpm, import and compile `export.xml` and then execute the Init() method to setup iris requirement.  

```
Do $SYSTEM.OBJ.Load("<git-directory>/iris-sql-dashboard/export.xml", "ck")
Do ##class(dc.sqlstats.services.Install).Init()
```


## Generate a key

If 
```

```