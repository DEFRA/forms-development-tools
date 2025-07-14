# Local Development Dependencies

This directory contains instructions and configuration for spinning up all local development dependencies required by the Defra Forms application suite using Docker Compose.

## Prerequisites
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/)

## Usage: Docker Compose

To start all dependencies using Docker Compose, run:

```sh
docker compose up
```

This will spin up all the necessary containers for local development of the Defra Forms.

To stop and remove the containers, run:

```sh
docker compose down
```

> For more information about the services and port mappings, refer to the main README and the `docker-compose.yml` file.
