# System configuration issues

This page lists issues related to specific system configuration (such as systemd, mkinitcpio, modprobe, etc.) that may degrade the entire system or specific features.

## Systemd hibernation does not work with NVIDIA early KMS

If the system have early KMS with NVIDIA modules (the `kms` hook and/or `nvidia*` modules in the initramfs config or `/etc/mkinitcpio.conf`), the NVIDIA driver gets loaded during initramfs/early boot and can't correctly perform its resume, especially in configurations using `NVreg_PreserveVideoMemoryAllocations=1` and `NVreg_TemporaryFilePath=...`.

Related error log in journal:

```
Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: dpm_run_callback(): pci_pm_freeze returns -5 Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: failed to quiesce async: error -5
Jan 01 02:17:43 archlinux kernel: PM: hibernation: Failed to load image, recovering.
```

### Solutions

1. Remove `kms` hook and `nvidia*` modules from initramfs.
    * **Drawback**: `plymouth` does not work, as it requires early KMS.
1. Use dual initramfs: (1) initramfs with `plymouth` and `kms`, (2) initramfs with `plymouth` and `kms` disabled, but with NVIDIA hibernation support (`NVreg_PreserveVideoMemoryAllocations`).
    * **Suggestion**: Can be configured with different `mkinitcpio.conf` presets and boot loader entries. For boot loader entries, this is easily configurable with `systemd-boot` in `/efi/loader/entries`.
