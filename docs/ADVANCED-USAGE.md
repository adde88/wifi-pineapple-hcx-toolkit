# Advanced Usage Guide (v6.5.0)

This guide covers advanced techniques for power users of the WiFi Pineapple HCX Toolkit.

## 1. Choosing an Attack Backend (`--backend`)

Version 6.0.0 introduced a selectable backend engine, allowing you to choose the right tool for your specific goal.

* **`hcxdumptool` (Default)**: The classic engine. Best for general-purpose, high-volume capture of handshakes and PMKIDs.
* **`hcxlabtool` (Advanced)**: A surgical tool for specialized attacks. Use this for stealthy client-only attacks or focusing exclusively on PMKIDs.

```bash
# This command uses the advanced backend for a stealthy attack
hcxdumptool-launcher --backend hcxlabtool --client-only-hunt -i wlan2