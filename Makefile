IMAGE_NAME:=gcr.io/example-gcp-project/mssng
IMAGE_VERSION:=dev
IMAGE_TAG=$(IMAGE_NAME):$(IMAGE_VERSION)
DEV_DB_CREDENTIAL=-uroot -prubyisallaround

default:
	@echo "No default job. Open Makefile for more info."

local-run:
	bundle exec rails server -b 0.0.0.0

public-release-review:
	@python script/make_os_release ../portal-service
	@echo "If you are ok with the result, run 'make public-release'."

public-release:
	python script/make_os_release --apply --reset ../portal-service

gcp-build:
	date +%s > .manually-deployed-version
	@echo "***** Trigger GCP build manually $$(cat .manually-deployed-version) *****"
	gcloud builds submit \
		--project=example-gcp-project \
		--config=cloudbuild.yml \
		--substitutions=BRANCH_NAME=master,SHORT_SHA=t$$(cat .manually-deployed-version)

docker-build: docker-build-portal docker-build-test-runner

docker-build-portal:
	docker build -t $(IMAGE_TAG) .

docker-build-test-runner:
	docker build -t $(IMAGE_TAG)-e2e -f e2e/Dockerfile .

docker-push:
	docker push $(IMAGE_TAG)

docker-pull:
	docker pull $(IMAGE_TAG)

docker-start:
	docker-compose up -d mysql test-runner
	docker-compose up --force-recreate -d portal

test-e2e:
	cd e2e && cucumber -v features/navigation.feature

remote-test-e2e:
	kubectl create job zero-test-runner-manual \
		--from=cronjob/test-runner-cronjob-test-daily \
		-n staging
	python3 ci/cloudbuild/step-verify-e2e-tests/main.py -n staging zero-test-runner-manual

dev-db-backup:
	docker-compose exec mysql bash -c "mysqldump $(DEV_DB_CREDENTIAL) --databases users_staging entrez_staging 2> /dev/null" > "dev-db-latest.sql"
	cp "dev-db-latest.sql" "dev-db-$$(date "+%Y%m%d-%H%M").sql"

dev-db-restore:
	docker run -it --rm --network "autism_default" -v $$(pwd):/opt mysql:5.7 bash -c "mysql -h mysql $(DEV_DB_CREDENTIAL) < /opt/dev-db-latest.sql"