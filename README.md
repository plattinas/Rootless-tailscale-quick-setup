# Tailscale_setup

Will download a selected tailscale executable and setup a service to run it with user permissions
## Usage

```bash
chmod +x ./tailscale_setup.sh
./tailscale_setup.sh
```
after instalation (you may need to open another terminal to update .bashrc), run:
```bash
tailscale up
```
then proced to login in your tailscale account
## Requirements

- bash 4+
- curl
- systemd

## Uninstalling

```bash
rm -r $HOME/tailscale $HOME/.config/systemd/user/tailscaled.service
unset ti_TAILSCALE_INSTALLED
systemctl --user disable --now tailscaled.service
systemctl --user daemon-reload
```
also, delete this from your .bashrc:
```bash
#Tailscale
export ti_TAILSCALE_INSTALLED=TRUE
source /home/gabriel/tailscale/.tailscale_bashrc
```
