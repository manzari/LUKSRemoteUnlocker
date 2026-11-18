# Server setup

What a Debian or Ubuntu server needs before the app or the CLI can unlock it. The app shows the same advice under Settings.

## 1. Dropbear in the initramfs

Install `dropbear-initramfs`, then set the options in `/etc/dropbear/initramfs/dropbear.conf`:

```sh
DROPBEAR_OPTIONS="-p 2222 -s -j -k -I 180 -c cryptroot-unlock"
```

Rebuild the initramfs afterwards:

```sh
update-initramfs -u
```

## 2. Pin the pre-boot host key

Print the fingerprint of the Dropbear host key on the server and paste it into the host form, or confirm it on the first connect:

```sh
dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key
```

## 3. A LUKS key slot for remote unlock

Add a dedicated passphrase in its own LUKS key slot, so a lost phone means removing one slot:

```sh
cryptsetup luksAddKey /dev/<disk>
```

## 4. One SSH key per device

Generate a separate SSH key on each device and add its public key to `/etc/dropbear/initramfs/authorized_keys`, so one device can be revoked by removing its line. Run `update-initramfs -u` again after changing that file.
