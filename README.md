# Defra Forms Development Tools

This repository contains shared development tools and infrastructure for the Defra Forms application suite.

## Overview

Currently, the repository provides a Docker Compose setup to help developers spin up all the required dependencies for the following services:

- **forms-designer**
- **forms-manager**
- **forms-runner**
- **forms-submission-api**

It includes the CDP uploader infrastructure relevant for `forms-runner` and `forms-submission-api`.

## Getting Started

### Prerequisites
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/)

### Usage: Docker Compose

To start all dependencies using Docker Compose, run:

```sh
docker compose up
```

This will spin up all the necessary containers for local development of the Defra Forms.

To stop and remove the containers, run:

```sh
docker compose down
```

## Notes
- This repository is intended for development and local testing only.
- For more information about each service, refer to their respective repositories.