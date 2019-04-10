The BDD tests has been refactored and moved to `e2e/`. Please see that folder.

## Why should you use/update the "e2e" version?

**The e2e version** is designed to run the end-to-end tests in isolation and make
the test runner portable, i.e., anyone can run the test from anywhere regardless
to the host machine without installing lots of hard-to-install dependencies.

Please read [how to test with local Docker](../docs/e2e-tests/local-docker.md) for more information.
