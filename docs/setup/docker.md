# Setup with Docker

This section is to describe how to get everything up and running with Docker and
Docker Compose. This is highly recommended for quick setup.

> **WARNING:** The `docker-compose.yml` is **NOT** suitable for production.

## Prerequisites

* Docker (latest)
* Docker Compose (latest)

## Getting started

### 1. Set the environment variables

First, you will need to copy `.env.dist` to `.env` (on the same directory).

```
cp .env.dist .env
```

Then, only set `GCP_CLIENT_ID` and `GCP_CLIENT_SECRET`, which you need to obtain from:

```
GCP Web Console → API & Services → Credentials
```

and get the client ID and secret for `web development` in **"OAuth 2.0 client IDs"**.

> With this method, the other environments are already overridden in `docker-compose.yml`.

### 2. Make the service image

Just run:
```
make docker-build
```

### 3. Start the service

Run:
```
make docker-start
```
to start services with Docker Compose.

## Notes

### Share volumes

When you start services with Docker Compose, the working copy is mount to the
working directory of the container. Any changes you made either on the host
machine or inside the container will apply to the working copy.

### Companion MySQL service

The portal service will always connect to the MySQL service specified in `docker-compose.yml`.

> The MySQL service is accessible from the host machine via the port specified
> in `docker-compose.yml`, e.g., `13306`.

### Access to the shell of the portal container

You can access to the shell of the portal container by running

```
docker-compose exec portal bash
```

### From the blank state

If you are running the setup for the first time, please follow steps **12** and **13** in **"How to setup"** for **"Run locally"** with some exceptions.

* To execute any `bundle` commands in this case, you may need to access to the
  shell of the container.
* As the portal service only communicates with the companion MySQL service, you
  will need to import schema/data to that MySQL service.
