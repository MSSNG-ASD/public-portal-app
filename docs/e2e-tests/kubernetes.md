# End-to-End Tests with Kubernetes

This is the guide on how to run end-to-end tests with the MSSNG Portal's
Kubernetes Cluster.

> This testing methods requires the cluster setup with `autism-deployment` (repo).

## Automatic Tests by Cloud Build Jobs

When you do Git push or run `make gcp-guild`, Google Cloud Build job will create
a Kubernetes job based on `test-runner-cronjob-test-daily` (Kubernetes Cron Job)
to run the tests.

For more information, see [MSSNG CI & CD Process](https://docs.google.com/drawings/d/1a6DjJ2t4-5A5X3efJpqwhLWETlP1_9Nlhh2XeM06dIs/edit).

## Test Rerun

In case that you want to rerun the test suite, you can trigger the tests with:

```
make remote-test-e2e
```

> This method will rebuild **neither** the portal service image nor the test
> runner image.

### Prerequisite

* `kubectl`
* Python
  * This is for the job status checking script.
  * For Mac users, it requires Python 3.6 or higher because the `six` package,
    required by the `kubernetes` package (python) that come with MacOS is not
    upgradable.
