# Ubuntu Web Node Configuration

An idempotent playbook installs Nginx, manages a lab virtual host, validates configuration, enables the service and checks `/healthz`. A handler reloads Nginx only when the managed configuration changes.

Use a disposable Ubuntu 24.04 VM with SSH access and sudo. The playbook replaces the default Nginx site, so the target should be dedicated to this lab. Run Ansible from Linux or WSL with ansible-core 2.18 installed.

```sh
cp inventory.ini.example inventory.ini
# Replace the example address and SSH user with your VM details.
ansible-playbook -i inventory.ini playbook.yml --syntax-check
ansible -i inventory.ini web -m ping
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass
```

Expected on the second run: `changed=0` when the host is already configured. Keep SSH host key checking enabled and authenticate with your existing SSH key or agent. No passwords belong in inventory. The endpoint uses HTTP inside the lab; production TLS termination is outside this project.

If the health check fails, inspect `sudo nginx -t`, `systemctl status nginx` and `journalctl -u nginx`. Cleanup: remove the disposable VM through the system that created it.
