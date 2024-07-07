.PHONY: all clone install provision encrypt decrypt help invent

SSH_USER=$(shell whoami)
HOSTNAME=$(shell hostname)
IP_ADDRESS=$(shell hostname -I | awk '{print $$1}')
MISSKEY_DIR=/var/www/misskey
AI_DIR=~/ai

all: install clone invent provision encrypt

install:
	sudo apt-get update
	sudo apt-get install -y ansible

clone:
	sudo mkdir -p $(MISSKEY_DIR)
	sudo chown $(USER):$(USER) $(MISSKEY_DIR)
	git clone https://github.com/yamisskey/yamisskey.git $(MISSKEY_DIR)
	cd $(MISSKEY_DIR) && git checkout master
	mkdir -p $(AI_DIR)
	git clone https://github.com/yamisskey/yui.git $(AI_DIR)

invent:
	echo "[servers]" > ansible/inventory
	echo "$(HOSTNAME) ansible_host=$(IP_ADDRESS) ansible_user=$(SSH_USER)" >> ansible/inventory
	echo "Inventory file created at ansible/inventory"

provision:
	ansible-playbook -i ansible/inventory ansible/playbooks/common.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/misskey.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/tor.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/ai.yml --ask-become-pass
	ansible-playbook -i ansible/inventory ansible/playbooks/monitoring.yml --ask-become-pass

CONFIG_FILES=$(MISSKEY_DIR)/.config/default.yml $(MISSKEY_DIR)/.config/docker.env

encrypt:
	ansible-vault encrypt $(CONFIG_FILES)

decrypt:
	ansible-vault decrypt $(CONFIG_FILES)

help:
	@echo "Available targets:"
	@echo "  all       - Install, clone, invent, provision, and encrypt"
	@echo "  install   - Update and install necessary packages"
	@echo "  clone     - Clone the misskey repository"
	@echo "  invent    - Create the Ansible inventory file automatically"
	@echo "  provision - Provision the server using Ansible"
	@echo "  encrypt   - Encrypt configuration files"
	@echo "  decrypt   - Decrypt configuration files"