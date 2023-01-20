0?=make scenario=<scenario>

help:
	@echo Usage: "${0} <command> [<command>]..."
	@echo
	@echo Available scenarios:
	@./scripts/scenarios.sh
	@echo
	@echo Current scenario: ${scenario}
	@echo
	@echo Available commands:
	@printf "\tinit\t Initialize and configure all dependencies to make tootbench ready to run.\n"
	@printf "\tsetup\t Deploy the scenarios infrastructure.\n"
	@printf "\tprepare\t Prepare benchmark: install services, certs, client; initialize database and create users.\n"
	@printf "\tstart\t Start monitoring, mastodon containers and client.\n"
	@printf "\tstop\t Stop client, mastodon containers and monitoring.\n"
	@printf "\tcollect\t Collect generated monitoring and client logs.\n"
	@printf "\tclean\t Clean monitoring and client logs on remote benchmark infrastructure.\n"
	@printf "\tanalyse\t Run analysis script on collected logs.\n"
	@printf "\tdestroy\t Destroy the scenarios infrastructure.\n"
	@echo
	@echo "Requirements:"
	@printf "\tDocker:     " && (docker version >/dev/null 2>/dev/null && printf "✅ " || printf "❌ " && echo " (mandatory)")
	@printf "\tOpenSSL:    " && (openssl version >/dev/null 2>/dev/null && echo "✅ " || echo "❌  (maybe use the docker image in ./gcloud-terraform/ instead - see below)")
	@printf "\tTerraform:  " && (terraform -version >/dev/null 2>/dev/null && echo "✅ " || echo "❌  (maybe use the docker image in ./gcloud-terraform/ instead - see below)")
	@printf "\tMaven:      " && (mvn --version >/dev/null 2>/dev/null && echo "✅ " || echo "⚠  (may use a docker container instead)")
	@printf "\tAnsible:    " && (ansible-playbook --version >/dev/null 2>/dev/null && echo "✅ " || echo "❌  (maybe use the docker image in ./gcloud-terraform/ instead - see below)")
	@printf "\tgcloud SDK: " && (gcloud --version >/dev/null 2>/dev/null && echo "✅ " || echo "❌  (maybe use the docker image in ./gcloud-terraform/ instead - see below)")
	@echo
	@printf "Alternatively, use the docker image in ./gcloud-terraform/ instead:\n\tdocker build -t gcloud-terraform:412 gcloud-terraform\n"
	@printf '\tdocker run --entrypoint /bin/bash -a \\\n\t   -v "$(PWD):/home/cloudsdk/project" \\\n\t   -v gcloud-config-personal:/home/cloudsdk/.config -v gcloud-config-root:/root/.config \\\n\t   -v /var/run/docker.sock:/var/run/docker.sock --name gcloud-terraform -u 1000:972 -w /home/cloudsdk/project \\\n\t   --env HOST_VOLUME_MOUNT=$(PWD) \\\n\t   gcloud-terraform:412\n'
	@echo

test:
	@./scripts/test.sh

init:


setup:
	@terraform -chdir=terraform init ${scenario}
	@terraform -chdir=terraform apply ${scenario}
	@./scripts/await-ssh.sh

restart:
	@./scripts/restart.sh

restart-client:
	@./scripts/restart.sh client

restart-instance:
	@./scripts/restart.sh instance

prepare:
	@ansible-playbook --inventory hosts.ini playbooks/prepare.yml

start:
	@ansible-playbook --inventory hosts.ini playbooks/start.yml

stop:
	@ansible-playbook --inventory hosts.ini playbooks/stop.yml

collect:
	@ansible-playbook --inventory hosts.ini playbooks/collect.yml

clean:
	@ansible-playbook --inventory hosts.ini playbooks/clean.yml

destroy:
	@terraform -chdir=terraform destroy ${scenario}

analyse:
