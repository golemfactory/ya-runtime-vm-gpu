# ya-runtime-vm-gpu

## Installation

Export GPU identifier in BDF (Bus Device Function) format as `PCI_DEVICE` environment variable and run installation script.

```bash
export PCI_DEVICE=_BDF_
curl -sSf https://github.com/golemfactory/ya-runtime-vm-nvidia/releases/latest/install.sh | bash -
```
