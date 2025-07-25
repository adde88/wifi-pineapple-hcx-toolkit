# Advanced Usage Guide (v7.0.0)

This guide covers advanced techniques for power users of the WiFi Pineapple HCX Toolkit.

## 1. Performance Optimization Engine

Version 7.0.0 introduces a powerful feature to dramatically boost capture performance by applying a wireless configuration fine-tuned for the WiFi Pineapple MKVII hardware. This can result in a significant increase in the number of captured handshakes and PMKIDs.

**WARNING**: This is an advanced feature that replaces your system's `/etc/config/wireless` file. The toolkit creates a backup, but you should understand the risks.

### Activating Performance Mode

To apply the optimized settings:
```bash
hcxdumptool-launcher --optimize-performance
```

The script will:  
1. Create a backup of your current wireless config at ```/etc/config/wireless.hcx-backup```.
2. Copy the new high-gain configuration template into place.  
3. Display a critical warning with manual steps you must perform.  
**IMPORTANT**: After running this command, you **MUST** follow the on-screen instructions, which include:  
* Manually editing /etc/config/wireless to set a secure password.  
* Running uci commit wireless.  
* Rebooting your device.  

**Restoring Your Original Configuration**  
To revert to your original settings at any time:  
```hcxdumptool-launcher --restore-config```
This will restore your original settings from the backup file and reload the WiFi services. A reboot is still recommended.

### Choosing an Attack Backend (--backend)  
Version 6.0.0 introduced a selectable backend engine, allowing you to choose the right tool for your specific goal.   
```hcxdumptool``` **(Default)**: The classic engine. Best for general-purpose, high-volume capture of handshakes and PMKIDs.  
```hcxlabtool``` **(Advanced)**: A surgical tool for specialized attacks. Use this for stealthy client-only attacks or focusing exclusively on PMKIDs.
```bash
# This command uses the advanced backend for a stealthy attack
hcxdumptool-launcher --backend hcxlabtool --client-only-hunt -i wlan2
```