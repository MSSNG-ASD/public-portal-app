# End-to-End tests

## What you should know before getting started

### Search Data Reset

As of now, the test runner relies on an existing (real) user, **please be aware
that only the search data will be reset** as needed by each test scenario.

### Test Helper Endpoints

The test runner will make requests to the test helper endpoints on the portal.
These endpoints are protected by a JSON Web Token (JWT) with 5-second-long TTL.

The endpoints is only enabled if the environment variable `TEST_JWT_SECRET` is
set and not an empty string.

#### JWT Generation and Validation

Please note that
* **The Portal Service** will only validate any given tokens.
* **The Test Runner** will only issue given tokens.

### What the test runner can/will do

* Run the tests against the local deployment or the remote deployment.
* In some test scenarios, the test runner will use the test helper endpoints to
  facilitate the data reset and user authentication.

### What the test runner will not do

* Directly manipulate the data in any databases.
* All data manipulation will be done indirectly via **Test Helper Endpoints**.

## Continue on

* [End-to-End Tests with Local Docker](local-docker.md)
* [End-to-End Tests with Kubernetes](kubernetes.md)