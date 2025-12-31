
# Systemd hibernation does not work with NVIDIA early KMS

If the system have early KMS with NVIDIA modules (the `kms` hook and/or `nvidia*` modules in the initramfs config or `/etc/mkinitcpio.conf`), the NVIDIA driver gets loaded during initramfs/early boot and can't correctly perform its resume, especially in configurations using `NVreg_PreserveVideoMemoryAllocations=1` and `NVreg_TemporaryFilePath`:

```
Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: dpm_run_callback(): pci_pm_freeze returns -5 Jan 01 02:17:43 archlinux kernel: nvidia 0000:07:00.0: PM: failed to quiesce async: error -5
Jan 01 02:17:43 archlinux kernel: PM: hibernation: Failed to load image, recovering.
```

## Solution

* Remove `kms` hook and `nvidia*` modules from initramfs.

## Drawback

* `plymouth` does not work, as it requires early KMS.