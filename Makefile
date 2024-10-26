.PHONY: all install inventory clone provision backup help migrate playbook run_playbook update

SSH_USER=$(shell whoami)
SOURCE_HOSTNAME=$(shell hostname)
SOURCE_IP=$(shell tailscale ip -4)
SOURCE_SSH_PORT=2222
DESTINATION_HOSTNAME=balthasar
DESTINATION_IP=$(shell tailscale status | grep $(DESTINATION_HOSTNAME) | awk '{print $$1}')
DESTINATION_SSH_PORT=22
OS=$(shell lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(shell lsb_release -cs)
USER=$(shell whoami)
TIMESTAMP=$(shell date +%Y%m%dT%H%M%S`date +%N | cut -c 1-6`)
MISSKEY_DIR=/var/www/misskey
CONFIG_FILES=$(MISSKEY_DIR)/.config/default.yml $(MISSKEY_DIR)/.config/docker.env
AI_DIR=$(HOME)/ai
BACKUP_SCRIPT_DIR=$(HOME)/misskey-backup
ANONOTE_DIR=$(HOME)/misskey-anonote
ASSETS_DIR=$(HOME)/misskey-assets
CTFD_DIR=$(HOME)/ctfd
PLAYBOOK_DIR=ansible/playbooks
ROLE_DIR=$(PLAYBOOK_DIR)/roles
ENV_FILE=.env

# Load environment variables if .env file exists
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
    export $(shell sed 's/=.*//' $(ENV_FILE))
endif

all: install inventory clone provision backup

install:
	@echo "Installing necessary packages..."
	@sudo apt-get update && sudo apt-get install -y ansible || (echo "Install failed" && exit 1)
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/common.yml EXTRA_OPTS="--limit source"
	@curl -fsSL https://tailscale.com/install.sh | sh
	@curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
	@echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(CODENAME) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
	@sudo apt-get update && sudo apt-get install -y cloudflare-warp
	#@curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
	#@echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(CODENAME) main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

inventory:
	@echo "Creating inventory file..."
	@echo "[source]\n$(SOURCE_HOSTNAME) ansible_host=$(SOURCE_IP) ansible_user=$(SSH_USER) ansible_port=$(SOURCE_SSH_PORT) ansible_become=true" > ansible/inventory
	@echo "[destination]\n$(DESTINATION_HOSTNAME) ansible_host=$(DESTINATION_IP) ansible_user=$(SSH_USER) ansible_port=$(DESTINATION_SSH_PORT) ansible_become=true" >> ansible/inventory
	@echo "Inventory file created at ansible/inventory"

run_playbook:
	@echo "Running playbook: $(PLAYBOOK)"
	@ansible-playbook -i ansible/inventory --ask-become-pass $(EXTRA_OPTS) $(PLAYBOOK) || (echo "Playbook $(PLAYBOOK) failed" && exit 1)

common:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/common.yml EXTRA_OPTS="--limit source"

security:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/security.yml EXTRA_OPTS="--limit source"

misskey:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/misskey.yml EXTRA_OPTS="--limit source"

ai:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/ai.yml EXTRA_OPTS="--limit source"

jitsi:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/jitsi.yml EXTRA_OPTS="--limit source"

minio:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/minio.yml EXTRA_OPTS="--limit source"

matrix:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/matrix.yml EXTRA_OPTS="--limit source"

monitoring:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/monitoring.yml EXTRA_OPTS="--limit source"

tor:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/tor.yml EXTRA_OPTS="--limit source"

vikunja:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/vikunja.yml EXTRA_OPTS="--limit source"

migrate:
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/migrate.yml

clone:
	@echo "Cloning repositories if not already present..."
	sudo mkdir -p $(MISSKEY_DIR)
	sudo chown $(USER):$(USER) $(MISSKEY_DIR)
	if [ ! -d "$(MISSKEY_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yamisskey.git $(MISSKEY_DIR); \
		cd $(MISSKEY_DIR) && git checkout master; \
	fi
	sudo mkdir -p $(ASSETS_DIR)
	sudo chown $(USER):$(USER) $(ASSETS_DIR)
	if [ ! -d "$(ASSETS_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yamisskey-assets.git $(ASSETS_DIR); \
	fi
	mkdir -p $(AI_DIR)
	if [ ! -d "$(AI_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yui.git $(AI_DIR); \
	fi
	mkdir -p $(BACKUP_SCRIPT_DIR)
	if [ ! -d "$(BACKUP_SCRIPT_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yamisskey-backup.git $(BACKUP_SCRIPT_DIR); \
	fi
	mkdir -p $(ANONOTE_DIR)
	if [ ! -d "$(ANONOTE_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yamisskey-anonote.git $(ANONOTE_DIR); \
	fi
	mkdir -p $(CTFD_DIR)
	if [ ! -d "$(CTFD_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/ctf.yami.ski.git $(CTFD_DIR); \
	fi

provision:
	@echo "Running provision playbooks..."
	@$(MAKE) common
	@$(MAKE) security
	@$(MAKE) monitoring
	@$(MAKE) minio
	@$(MAKE) misskey
	@$(MAKE) ai
	@$(MAKE) tor
	@$(MAKE) matrix
	@$(MAKE) jitsi
	@$(MAKE) vikunja

backup:
	@echo "Converting .env to env.yml and running backup..."
	@echo "---" > $(BACKUP_SCRIPT_DIR)/env.yml
	@awk -F '=' '/^[^#]/ {print $$1 ": " $$2}' $(BACKUP_SCRIPT_DIR)/.env >> $(BACKUP_SCRIPT_DIR)/env.yml
	@sudo cp $(BACKUP_SCRIPT_DIR)/env.yml /opt/misskey-backup/config/env.yml
	@$(MAKE) run_playbook PLAYBOOK=$(PLAYBOOK_DIR)/misskey-backup.yml

update:
	@echo "Updating Misskey..."
	cd $(MISSKEY_DIR) && sudo docker-compose down
	cd $(MISSKEY_DIR) && sudo git stash || true
	cd $(MISSKEY_DIR) && git checkout master && sudo git pull origin master
	cd $(MISSKEY_DIR) && sudo git submodule update --init
	cd $(MISSKEY_DIR) && git stash pop || true
	cd $(MISSKEY_DIR) && sudo COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build --no-cache --build-arg TAG=misskey_web:$(TIMESTAMP)
	cd $(MISSKEY_DIR) && sudo docker tag misskey_web:latest misskey_web:$(TIMESTAMP)
	cd $(MISSKEY_DIR) && sudo docker compose stop && sudo docker compose up -d

help:
	@echo "Available targets:"
	@echo "  all       - Install, clone, setup, provision, and backup"
	@echo "  install   - Update and install necessary packages"
	@echo "  inventory - Create the Ansible inventory"
	@echo "  clone     - Clone the repositories if they don't exist"
	@echo "  provision - Provision the server using Ansible"
	@echo "  backup    - Run the backup playbook"
	@echo "  update    - Update Misskey and rebuild Docker images"
	@echo "  common, security, misskey, ai, jitsi, minio, matrix, monitoring, tor, vikunja, migrate - Run specific playbooks"