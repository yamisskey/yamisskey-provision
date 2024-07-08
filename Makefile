.PHONY: all install clone provision backup encrypt decrypt help

SSH_USER=$(shell whoami)
HOSTNAME=$(shell hostname)
IP_ADDRESS=$(shell hostname -I | awk '{print $$1}')
SSH_PORT=2222
MISSKEY_DIR=/var/www/misskey
CONFIG_FILES=$(MISSKEY_DIR)/.config/default.yml $(MISSKEY_DIR)/.config/docker.env
AI_DIR=$(HOME)/ai
BACKUP_SCRIPT_DIR=$(HOME)/misskey-backup

all: install clone provision encrypt

install:
	sudo apt-get update
	sudo apt-get install -y ansible
	echo "[servers]" > ansible/inventory
	echo "$(HOSTNAME) ansible_host=$(IP_ADDRESS) ansible_user=$(SSH_USER) ansible_port=$(SSH_PORT)" >> ansible/inventory
	echo "Inventory file created at ansible/inventory"

clone:
	sudo mkdir -p $(MISSKEY_DIR)
	sudo chown $(USER):$(USER) $(MISSKEY_DIR)
	if [ ! -d "$(MISSKEY_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yamisskey.git $(MISSKEY_DIR); \
		cd $(MISSKEY_DIR) && git checkout master; \
	fi
	mkdir -p $(AI_DIR)
	if [ ! -d "$(AI_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yui.git $(AI_DIR); \
	fi
	mkdir -p $(BACKUP_SCRIPT_DIR)
	if [ ! -d "$(BACKUP_SCRIPT_DIR)/.git" ]; then \
		git clone https://github.com/yamisskey/yamisskey-backup.git $(BACKUP_SCRIPT_DIR); \
	fi

provision:
	ansible-playbook -i ansible/inventory ansible/playbooks/common.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/misskey.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/tor.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/ai.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/monitoring.yml --ask-become-pass

backup:
	@echo "Converting .env to env.yml..."
	@echo "---" > $(BACKUP_SCRIPT_DIR)/env.yml
	@while IFS= read -r line; do \
	  if [ ! "$$line" = "${line#\#}" -a ! -z "$$line" ]; then \
	    key=$$(echo $$line | cut -d '=' -f 1); \
	    value=$$(echo $$line | cut -d '=' -f 2-); \
	    echo "$$key: $$value" >> $(BACKUP_SCRIPT_DIR)/env.yml; \
	  fi; \
	done < $(BACKUP_SCRIPT_DIR)/.env
	@echo "Moving env.yml to target directory..."                                                                                                  │
	sudo cp $(BACKUP_SCRIPT_DIR)/env.yml /opt/misskey-backup/config/env.yml   
	@echo "Running backup script..."
	ansible-playbook -i ansible/inventory ansible/playbooks/misskey-backup.yml --ask-become-pass
	@echo "Running manual backup script..."
	sudo docker exec backup /root/backup.sh

encrypt:
	ansible-vault encrypt $(CONFIG_FILES)

decrypt:
	ansible-vault decrypt $(CONFIG_FILES)

help:
	@echo "Available targets:"
	@echo "  all       - Install, clone, invent, provision, and encrypt"
	@echo "  install   - Update and install necessary packages"
	@echo "  clone     - Clone the misskey repository if it doesn't exist"
	@echo "  provision - Provision the server using Ansible"
	@echo "  backup    - Run the backup playbook"
	@echo "  encrypt   - Encrypt configuration files"
	@echo "  decrypt   - Decrypt configuration files"