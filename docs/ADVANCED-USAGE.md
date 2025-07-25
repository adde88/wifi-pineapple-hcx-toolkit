# Advanced Usage Guide (v7.0.0)

This guide covers advanced techniques for power users of the WiFi Pineapple HCX Toolkit.

## 1. Remote Execution Engine

The flagship feature of v7.0.0 is the ability to offload intensive work to a more powerful machine. This avoids memory/CPU bottlenecks on the Pineapple and enables workflows that were previously impossible.

**Configuration**: All remote settings are managed in `/etc/hcxtools/hcxscript.conf`. You must configure your remote host IP, user, and paths here first. Passwordless SSH key authentication is required.

### Remote Analysis & Utilities
Almost any analysis task can be offloaded. The script handles the secure transfer of files, remote execution, and retrieval of results.

```bash
# Analyze a local capture file on the remote server and get the results back
hcx-analyzer.sh --remote-mode summary /root/hcxdumps/capture.pcapng

# Filter a hash file on the remote server and get the filtered file back
hcx-analyzer.sh --remote-utility filter_hashes --essid-regex "Guest.*" all_hashes.hc22000  

**Remote Cracking & Database Logging**
* ```--utility remote_crack```: Offloads a hash file to a remote Hashcat server for cracking.  
* ```--remote-mode mysql```: Logs analysis results directly to a remote MySQL database.

## 2. Performance Optimization Engine  
Version 7.0.0 introduces a feature to dramatically boost capture performance by applying a wireless configuration fine-tuned for the WiFi Pineapple MKVII hardware, potentially increasing capture rates by over 450%.  

**WARNING**: This is an advanced feature that replaces your system's ```/etc/config/wireless``` file. The toolkit creates a backup, but you should understand the risks.  

**Activating Performance Mode**
To apply the optimized settings:
```bash
hcxdumptool-launcher --optimize-performance
```  

The script will copy the template into place and display the following critical warning. You must follow these steps precisely.

############################################################################
ACTION REQUIRED: MANUAL CONFIGURATION AND REBOOT NEEDED!
############################################################################
The high-performance wireless configuration has been copied into place.
1. !! IMMEDIATE SECURITY RISK !!
The new configuration has a DEFAULT PASSWORD for the 'MK7-ADMIN' network.
You MUST change this password now.

EDIT THE FILE: /etc/config/wireless

FIND THE LINE: option key 'SETYOURADMINPASSWORDHERE'

CHANGE THE PASSWORD to a secure one.

2. !! APPLY CHANGES & REBOOT !!
To ensure these deep hardware changes are applied correctly, you must
commit the changes and then REBOOT your device.

Run these two commands now:
uci commit wireless
reboot

To revert these changes at any time, run:
hcxdumptool-launcher --restore-config
############################################################################

**Restoring Your Original Configuration**
To revert to your original settings at any time:  
```bash
hcxdumptool-launcher --restore-config
```  

## 3. Dual-Backend Attack System (--backend)  
You can now choose the capture engine best suited for your goal.  
```hcxdumptool``` (Default): The classic engine. A powerful, all-purpose tool for high-volume capture of both handshakes and PMKIDs.  
```hcxlabtool``` (Advanced): A surgical tool for specialized attacks. Use this when you need stealth or a very specific target type.  
```bash
# Use the advanced backend for a stealthy client-only attack
hcxdumptool-launcher --backend hcxlabtool --client-only-hunt -i wlan2
```

## 4. Specialized Attack Modes (hcxlabtool backend)  
These modes require using ```--backend hcxlabtool```.

* ```--client-only-hunt```: Stealthily captures client handshakes without ever associating with an AP. Excellent for passive, targeted collection.  
* ```--pmkid-priority-hunt```: Focuses exclusively on capturing PMKIDs from roaming-capable APs, ignoring client handshakes.  
* ```--time-warp-attack```: An advanced attack that sends future-dated beacon frames (--ftc), useful for specific security assessments.  

## 5. Advanced Filtering
**Capture-Time Filtering (Launcher)**  
Filter devices during capture to reduce noise. These flags generate a BPF filter on the fly.  
```bash
# Blacklist your own devices to avoid capturing them
hcxdumptool-launcher -i wlan2 --filter-file my_devices.txt --filter-mode blacklist

# Whitelist and target only a specific vendor's devices
hcxdumptool-launcher -i wlan2 --backend hcxlabtool --oui-file cisco_ouis.txt --oui-filter-mode whitelist
```

**Post-Capture Filtering (Analyzer)**
The analyzer provides powerful hash filtering capabilities.  
```bash
# Create a new hash file containing only authorized EAPOL handshakes for ESSIDs matching a regex
hcx-analyzer.sh --utility filter_hashes -o authorized_nets.hc22000 --type 2 --authorized --essid-regex "^HOME-" all_hashes.hc22000
```

## 6. Wardriving and Geotracking
* ```--wardriving-loop <seconds>```: Runs captures in continuous, timed loops, creating a new file for each loop. Perfect for mobile data collection.  
* ```--enable-gps```: When a gpsd-compatible device is connected, this embeds GPS data directly into the .pcapng file.  
* ```--utility geotrack```: After a wardriving session, use the analyzer to convert the GPS data from your captures into a KML map file.  
```bash
# Process all captures from the default directory to create a map
hcx-analyzer.sh --utility geotrack /root/hcxdumps/
```


