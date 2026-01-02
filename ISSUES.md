# Common system issues

This page lists issues related to specific system configuration (such as systemd, mkinitcpio, modprobe, etc.) that may degrade the entire system or specific features.

## Systemd hibernation does not work with NVIDIA early KMS

If the system have early KMS with NVIDIA modules (the `kms` hook and/or `nvidia*` modules in the initramfs config or `/etc/mkinitcpio.conf`), the NVIDIA driver gets loaded during initramfs/early boot and can't correctly perform its resume, especially in configurations using `NVreg_PreserveVideoMemoryAllocations=1` and `NVreg_TemporaryFilePath=...`.

Related error log in journal:

```
Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: dpm_run_callback(): pci_pm_freeze returns -5 Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: failed to quiesce async: error -5
Jan 01 02:17:43 archlinux kernel: PM: hibernation: Failed to load image, recovering.
```

**Note**: For computers/laptops with hybrid or dual GPU, if the primary GPU used for the system (or perhaps DE) is non-NVIDIA GPU, and the secondary NVIDIA GPU is not used (likely near 0%-5% usage on `btop`), then this will not affect.

### Solutions

1. Remove `kms` hook and `nvidia*` modules from initramfs.
    * **Drawback**: `plymouth` does not work, as it requires early KMS.
1. Use dual initramfs: (1) initramfs with `plymouth` and `kms`, (2) initramfs with `plymouth` and `kms` disabled, but with NVIDIA hibernation support (`NVreg_PreserveVideoMemoryAllocations`).
    * Can be configured with different `mkinitcpio.conf` presets.
    * Can be configured with boot loader entries loading different initramfs. For boot loader entries, this is easily configurable with `systemd-boot` in `/efi/loader/entries`.
        * For singular boot loader entry, consider automatically setting up oneshot boot before hibernation triggers (in systemd-boot, this may be `bootctl set-oneshot`).

## KDE Plasma using QPainter/software rendering instead of OpenGL/GPU rendering due to optimus-manager in a single dGPU setup

An issue where `optimus-manager` forces software rendering (QPainter) for KDE Plasma instead of GPU rendering on a system with a single discrete GPU.