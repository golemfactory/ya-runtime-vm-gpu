# ya-runtime-vm-gpu

$${\color{red}WARNING! }$$

Please be aware that this experimental runtime's (`ya-runtime-vm-nvidia`) goal is to provide GPU support to Golem Network. If configured correctly it will make your GPU available as a resource on Golem Network via PCI Passthrough.

It is an experimental feature in its very early stage and consequently comes with **NO** guarantees. It was tested on a limited number of hosts and supports Nvidia GPU only. Downloading and installing this runtime (`ya-runtime-vm-nvidia`) is not sufficient to make this experimental feature to work. Some changes on host setup itself are required too. High level instruction of such changes and other important information should be available in this Github Repository.

As an extremely experimental feature Golem Factory gives **NO** guarantees regarding its security or that it will even work. There is a chance that Golem Factory will not be able to help you out in case that something does not work or go wrong. Please proceed with caution.

If still in doubt please refer to Disclaimer, User Interaction Guidelines and Privacy Policy available at Golem webpage: https://www.golem.network/

## Installation

Export GPU identifier in BDF (Bus Device Function) format as `PCI_DEVICE` environment variable and run installation script.

```bash
export PCI_DEVICE=_BDF_
curl -sSf https://github.com/golemfactory/ya-runtime-vm-nvidia/releases/latest/install.sh | bash -
```
