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

### Local Development Dependencies
Instructions for running all local dependencies with Docker Compose can be found in [`local-development-dependencies/README.md`](./local-development-dependencies/README.md).

## Notes
- This repository is intended for development and local testing only.
- For more information about each service, refer to their respective repositories.