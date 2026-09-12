# Operators

NVIDIA GPU Operator, Flux, and Soperator are Helm/kubectl in **`terraform/platform`**. Network Operator is not installed (no InfiniBand).

Flux is required by Soperator (HelmReleases). Do not delete Flux.

Do not install the same charts from the Nebius console as well — that dual-installs them.

`driver.enabled=false` because this lab uses MK8s driverfull images.
