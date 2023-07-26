# ya-runtime-vm-nvidia

$${\color{red}WARNING! }$$

Please be aware that this experimental runtime's (`ya-runtime-vm-nvidia`) goal is to provide GPU support to Golem Network. If configured correctly it will make your GPU available as a resource on Golem Network via PCI Passthrough.

It is an experimental feature in its very early stage and consequently comes with **NO** guarantees. It was tested on a limited number of hosts and supports Nvidia GPU only. Downloading and installing this runtime (`ya-runtime-vm-nvidia`) is not sufficient to make this experimental feature to work. Some changes on host setup itself are required too. High level instruction of such changes and other important information should be available in this Github Repository.

As an extremely experimental feature Golem Factory gives **NO** guarantees regarding its security or that it will even work. There is a chance that Golem Factory will not be able to help you out in case that something does not work or go wrong. Please proceed with caution.

If still in doubt please refer to Disclaimer, User Interaction Guidelines and Privacy Policy available at Golem webpage: https://www.golem.network/

## Installation

Export GPU's BDF[^1] (Bus Device Function) as the `YA_RUNTIME_VM_PCI_DEVICE` environment variable (replace `_BDF_` with correct value). Then run installation script:

```bash
export YA_RUNTIME_VM_PCI_DEVICE="_BDF_"
curl -sSLf https://github.com/golemfactory/ya-runtime-vm-nvidia/releases/latest/download/install.sh | bash -
```

[^1]: GPU BDFs can be found in the first column of `lspci` command output. Use printed by `lspci` default representation of colon separated hexadecimal numbers.

Optional environment variables to adjust installation (with default values)

```bash
# Name pf the new runtime and preset
YA_INSTALLER_RUNTIME_ID=vm-nvidia
# Default price for the preset setup
YA_INSTALLER_GLM_PER_HOUR=0.025
# Default init price for the preset setup
YA_INSTALLER_INIT_PRICE=0
# Default location of provider config directory
DATA_DIR=~/.local/share/ya-provider
```

## Apps

Apps meant to be executed on `ya-runtime-vm-nvidia` should use [golem-nvidia-base](golem_nvidia_base/README.md) as a base image.

In order to match with GPU offering provider an app needs to list `!exp:gpu` among its required [capabilities](https://yapapi.readthedocs.io/en/latest/api.html#module-yapapi.payload.vm).
