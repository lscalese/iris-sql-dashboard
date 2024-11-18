## iris-sql-dashboard

This project is designed to provide an API for collecting and analyzing statistics of SQL queries executed in an IRIS database. It uses Docker to facilitate the deployment and execution of the application. The main features include collecting execution statistics of SQL queries, such as the number of executions, average execution time, and other relevant metrics. These statistics can then be visualized and analyzed using Grafana dashboards.


## Prerequisites
Make sure you have [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and [Docker desktop](https://www.docker.com/products/docker-desktop) installed.

## Installation 

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

