# End-to-End Tests with Docker

This is the guide on how to run end-to-end tests with **your local Docker service**.

## Prerequisite

Same as [setting up the portal with Docker](setup-with-docker.md).

## Getting started

### 1. Set the environment variables

First, you will need to copy `.env.dist` to `.env` (on the same directory).

```
cp .env.dist .env
```

Then, only set the environment variables that you need:

> This is used by `docker-compose`.

#### Applicable to Portal Service and Test Runner

> This is also applicable to the deployment on Kubernetes.

This is for JWT generation and validation.

| Environment Variable | Description | How to obtain the value |
| --- | --- | --- |
| `TEST_JWT_SECRET` | JWT Secret for the test helper endpoints | Any random string; the hexidecimal representation of version 4 UUID is highly recommended. | (See the note below.)

#### Applicable to only Test Runner

> This is also applicable to the deployment on Kubernetes.

This is for OAuth callback simulation.

| Environment Variable | Description |
| --- | --- |
| `TEST_AUTH_ACCESS_TOKEN` | Access Token |
| `TEST_AUTH_EMAIL` | User E-mail |
| `TEST_AUTH_EXPIRATION_TIME` | Refresh Token Expiration Time |
| `TEST_AUTH_REFRESH_TOKEN` | Refresh Token |
| `TEST_AUTH_UID` | User ID |

You can use this query to obtain the values.

``` sql
SELECT
    `token`         AS `TEST_AUTH_ACCESS_TOKEN`,
    `email`         AS `TEST_AUTH_EMAIL`,
    `expires_at`    AS `TEST_AUTH_EXPIRATION_TIME`,
    `refresh_token` AS `TEST_AUTH_REFRESH_TOKEN`
    `uid`           AS `TEST_AUTH_UID`,
FROM mssng_users.users
WHERE email = :email
LIMIT 1
```

> **Note:** The DB name could be different depending on the initial DB setup.

### 2. Make the test runner image

Just run:
```
make docker-build-test-runner
```

### 3. Start the container

Just run:
```
docker-compose up -d test-runner
```

> This service is set to run `tail -f /dev/null` by default to keep the container alive.

## Use the test runner

### Get the shell of the test runner

You can get the shell by running:

```
docker-compose exec test-runner bash
```

or use `docker exec -it <container_name_defined_in_yaml_file>`.

> At this point, the default working directory (`/opt/mssng_porta/e2e`) is
> mounted (in the read-write mode) with the folder `e2e` of your local copy.

### How to run the tests

The container of the test runner is set up with

* Cucumber
* Google Chrome
* Selenium with Google Chrome Driver

By default, when you run `cucumber`, `cucumber` will run against the portal
service that has been [set up with Docker](setup-with-docker.md) and accessible
at `http://portal:3000`). However, you may override the setting by setting or
exporting the environment variable `ROOT_URL` to where you want it to run. Here
is an example.

```bash
export ROOT_URL=https://beta.research.mss.ng
export TEST_JWT_SECRET=asdf1234

cucumber --fail-fast -t @auth_user
```

> You may also need to override `TEST_JWT_SECRET` as each deployment of the
> portal service uses different secrets.