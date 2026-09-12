locals {
  supported_gpu_driver_presets = {
    gpu-l40s-a     = ["cuda13.0"]
    gpu-l40s-d     = ["cuda13.0"]
    gpu-h100-sxm   = ["cuda13.0"]
    gpu-h200-sxm   = ["cuda13.0"]
    gpu-b200-sxm   = ["cuda13.0"]
    gpu-b200-sxm-a = ["cuda13.0"]
    gpu-b300-sxm   = ["cuda13.0"]
    gpu-rtx6000    = ["cuda13.0"]
    gpu-gb300      = ["cuda13.0"]
  }

  worker_gpu_platforms = distinct([
    for worker in var.slurm_nodeset_workers : worker.resource.platform
    if startswith(worker.resource.platform, "gpu-")
  ])
}

resource "terraform_data" "check_driver_presets" {
  lifecycle {
    precondition {
      condition = alltrue([
        for platform in local.worker_gpu_platforms :
        contains(keys(local.supported_gpu_driver_presets), platform)
      ])
      error_message = format(
        "No preinstalled CUDA 13.0 image for: %s",
        join(", ", setsubtract(toset(local.worker_gpu_platforms), toset(keys(local.supported_gpu_driver_presets))))
      )
    }
  }
}
