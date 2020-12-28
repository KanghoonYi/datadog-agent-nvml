# datadog-agent-nvml
for using nvidia graphic metric on datadog   
this project is working with docker.
## What is NVML?
Monitoring NVIDIA GPUs status using Datadog.   
see https://github.com/ngi644/datadog_nvml  
see https://developer.nvidia.com/nvidia-management-library-nvml
## Usage
### build
```
docker build -t datadog-nvml:latest .
docker build --build-arg DD_PYTHON_VERSION=3 -t datadog-nvml:latest .
```
#### build argument
> You can use `DD_IMAGE_TAG`, `CUDA_IMAGE_TAG`, `WITH_JMX`, `DD_PYTHON_VERSION`

* DD_IMAGE_TAG
  - datadog-agent docker image tag
  - see https://hub.docker.com/r/datadog/agent
* CUDA_IMAGE_TAG
  - Cuda docker image tag
  - see https://hub.docker.com/r/nvidia/cuda/tags?page=1&ordering=last_updated
* WITH_JMX 
  - If set to true, the Agent container contains the JMX fetch logic.
  - see https://docs.datadoghq.com/agent/guide/build-container-agent/?tab=amd
* DD_PYTHON_VERSION
  - The Python runtime version for your Agent check.
  - see https://docs.datadoghq.com/agent/guide/build-container-agent/?tab=amd

### Run image
```
docker run --env DD_API_KEY=test datadog-nvml:latest
```
>see below link to using environment variable
> >[https://docs.datadoghq.com/agent/docker/?tab=standard#environment-variables](https://docs.datadoghq.com/agent/docker/?tab=standard#environment-variables)


## ETC
Also, This Docker image can be used on Computing Server that is not support GPU.
If this image(datadog-agent-nvml) is deployed to server(none GPU), error is logged like below.
**This error occured just one time on initialzing process.**
```
2020-12-28 11:39:23 UTC | CORE | ERROR | (pkg/collector/python/loader.go:228 in addExpvarConfigureError) | py.loader: could not configure check 'nvml (0.1.5)': could not invoke 'nvml' python check constructor. New constructor API returned:
Traceback (most recent call last):
  File "/opt/datadog-agent/embedded/lib/python3.8/site-packages/pynvml.py", line 644, in _LoadNvmlLibrary
    nvmlLib = CDLL("libnvidia-ml.so.1")
  File "/opt/datadog-agent/embedded/lib/python3.8/ctypes/__init__.py", line 373, in __init__
    self._handle = _dlopen(self._name, mode)
OSError: libnvidia-ml.so.1: cannot open shared object file: No such file or directory
During handling of the above exception, another exception occurred:
Traceback (most recent call last):
  File "/etc/datadog-agent/checks.d/nvml.py", line 46, in __init__
    pynvml.nvmlInit()
  File "/opt/datadog-agent/embedded/lib/python3.8/site-packages/pynvml.py", line 608, in nvmlInit
    _LoadNvmlLibrary()
  File "/opt/datadog-agent/embedded/lib/python3.8/site-packages/pynvml.py", line 646, in _LoadNvmlLibrary
    _nvmlCheckReturn(NVML_ERROR_LIBRARY_NOT_FOUND)
  File "/opt/datadog-agent/embedded/lib/python3.8/site-packages/pynvml.py", line 310, in _nvmlCheckReturn
    raise NVMLError(ret)
pynvml.NVMLError_LibraryNotFound: NVML Shared Library Not Found
Deprecated constructor API returned:
__init__() got an unexpected keyword argument 'agentConfig'
```
For example, maybe you want to set just one datadog daemonset on Kubernetes (k8s).
Then, use this.

## Error reporting
If you have problem on using this project, please report to `issue`tab  
[issue](https://github.com/KanghoonYi/datadog-agent-nvml/issues)
