# Setup VPS with Makefile and Ansible Playbook

This guide will walk you through the process of setting up Misskey using the provided Makefile and Ansible playbook.

## Steps

0. Prepare to log in to VPS as a general user with SSH private key:

```consol
adduser your_username
usermod -aG sudo your_username
vi /etc/ssh/sshd_config
```

`/etc/ssh/sshd_config`

```config
RSAAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin  no
```

```consol
systemctl restart sshd
su your_username
mkdir .ssh
cd .ssh/
vi ~/.ssh/id_ed25519_vps.pub
touch ~/authrized_keys
cat ./id_ed25519_vps.pub >>  ./authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

1. Clone the provision repository from GitLab to your local machine:

`~/.ssh/config`

```config
Host vps.com
    User your_username
    port 22
    Hostname 00.000.000.000
    IdentityFile ~/.ssh/id_ed25519_vps
    TCPKeepAlive yes
    IdentitiesOnly yes
```

```consol
ssh vps.com
git clone https://github.com/yamisskey/provision.git
cd provision
```

2. Use the Makefile to install the necessary packages and clone the misskey repository:

```consol
make install
make clone
```

3. Navigate to the `misskey` directory inside the misskey directory and copy the configuration file templates:

```consol
cd ~/misskey
cp docker-compose_example.yml docker-compose.yml
cd .config
cp docker_example.yml default.yml
cp docker_example.env docker.env
```

4. Edit the `docker-compose.yml` and `default.yml` and `docker.env` files, providing the appropriate configuration values. Refer to the comments within the files for guidance.

- Change 3000 port to 3001 which conflicts with grafana in `docker-compose.yml` and `default.yml`
- Change domain example.tld to yami.ski in `default.yml`
- Change host of db from localhost to db and host of redis from localhost to redis in `default.yml`
- Change name and user and pass in `default.yml` and `docker.env`

5. Configure your firewall and open ports to expose the Misskey server:

```consol
sudo ufw enable
sudo ufw default deny
sudo ufw limit 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 3000
sudo ufw status
sudo systemctl enable ufw
```

6. [Configure Nginx](https://misskey-hub.net/ja/docs/for-admin/install/resources/nginx/) to reverse proxy Misskey. Ensure the Misskey Nginx configuration `misskey.conf` is properly set up to handle HTTP to HTTPS redirection, WebSocket support, and SSL configuration.

- Change 3000 port to 3001 which conflicts with grafana
- Change domain example.tld to yami.ski

7. Prepare the Cloudflare API credentials file. Create a directory for Cloudflare configuration if it does not exist:

- Access https://dash.cloudflare.com/profile/api-tokens
- Select View for Global API Key
- Enter password to remove hCaptcha and select View

```consol
sudo mkdir /etc/cloudflare
sudo vi /etc/cloudflare/cloudflare.ini
```

Include the following content, replacing placeholders with your actual data:

```config
dns_cloudflare_email = your-email@example.com
dns_cloudflare_api_key = your-cloudflare-global-api-key
```

```consol
sudo chmod 600 /etc/cloudflare/cloudflare.ini
```

In addition, in order to access grafana with a subdomain, register the DNS record of grafana.yami.ski with cloudflare.

8. Obtain SSL certificate using Cloudflare DNS:

```consol
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare/cloudflare.ini --dns-cloudflare-propagation-seconds 60 --server https://acme-v02.api.letsencrypt.org/directory -d yami.ski -d *.yami.ski -m yamisskey@proton.me
```

9. You need to manually prepare the configuration file `config.json` in ai repository to run:

```config
{
	"host": "https://yami.ski",
	"i": "唯として動かしたいアカウントのアクセストークン",
	"master": "admin",
	"notingEnabled": "ランダムにノートを投稿する機能を無効にする場合は false を入れる",
	"keywordEnabled": "キーワードを覚える機能 (MeCab が必要) を有効にする場合は true を入れる (無効にする場合は false)",
	"chartEnabled": "チャート機能を無効化する場合は false を入れてください",
	"reversiEnabled": "藍とリバーシで対局できる機能を有効にする場合は true を入れる (無効にする場合は false)",
	"serverMonitoring": "サーバー監視の機能を有効にする場合は true を入れる (無効にする場合は false)",
	"checkEmojisEnabled": "カスタム絵文字チェック機能を有効にする場合は true を入れる (無効にする場合は false)",
	"checkEmojisAtOnce": "カスタム絵文字チェック機能で投稿をまとめる場合は true を入れる (まとめない場合は false)",
	"mecab": "/usr/bin/mecab",
	"mecabDic": "/usr/lib/x86_64-linux-gnu/mecab/dic/mecab-ipadic-neologd/",
	"memoryDir": "data"
}
```

10. Return to the provision directory and use the Makefile to provision the server:

```consol
cd ~/provision
make provision
```

11. During the provisioning process, the Ansible playbook (playbook.yml) will pause and prompt you to review the configuration files you edited in step 4. Ensure that the configurations are correct, then press ENTER to continue the provisioning process.

12. Once the provisioning is complete, verify that Misskey is running correctly.

13. If needed, use the Makefile to encrypt the configuration files:

```consol
make encrypt
```

13. To decrypt the encrypted configuration files when necessary, run the following command:

```consol
make decrypt
```

14. Ensure that you have the necessary environment variables set up to backup. Create a .env file in the misskey-backup directory if it does not exist, and provide the required values:

```config
POSTGRES_HOST=your_postgres_host_in_misskey_config
POSTGRES_USER=your_postgres_user_in_misskey_config
POSTGRES_DB=your_postgres_namein_misskey_config
POSTGRES_PASSWORD=your_postgres_passwordin_misskey_config
R2_PREFIX=your_cloudflare_r2_bucket_prefix
DISCORD_WEBHOOK_URL=your_discord_server_channel_webhook_url
NOTIFICATION=true
```

```consol
make backup
```