#!/usr/bin/env bash
# Install workstation tools used by this repo. Skips anything already on PATH.
# macOS: Homebrew. Linux: apt when available.
# Run with bash (./scripts/00-install_prereqs.sh). zsh is fine as the login shell.
set -euo pipefail

# Terraform >= 1.12, Nebius CLI, kubectl, Helm, jq, mikefarah yq, GNU coreutils (md5sum).

have() {
  command -v "$1" >/dev/null 2>&1
}

# GNU md5sum, not BSD md5.
have_md5sum() {
  if have md5sum && md5sum --version >/dev/null 2>&1; then
    return 0
  fi
  have gmd5sum
}

# mikefarah yq (yq '.path'), not kislyuk/yq.
have_yq() {
  have yq
}

os="$(uname -s)"
missing=()
present=()

note() {
  local name="$1"
  shift
  if "$@"; then
    present+=("${name}")
  else
    missing+=("${name}")
  fi
}

note terraform have terraform
note nebius have nebius
note kubectl have kubectl
note helm have helm
note jq have jq
note yq have_yq
note coreutils have_md5sum

if [[ ${#present[@]} -eq 0 ]]; then
  echo "Already installed: none"
else
  echo "Already installed: ${present[*]}"
fi

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "All prerequisites are on PATH."
  terraform version | head -n 1 || true
  nebius version 2>/dev/null || true
  kubectl version --client 2>/dev/null | head -n 1 || true
  exit 0
fi

echo "Missing: ${missing[*]}"

install_brew_pkgs() {
  local pkgs=()
  for name in "${missing[@]}"; do
    case "${name}" in
      terraform) pkgs+=("hashicorp/tap/terraform") ;;
      kubectl) pkgs+=("kubernetes-cli") ;;
      helm) pkgs+=("helm") ;;
      jq) pkgs+=("jq") ;;
      yq) pkgs+=("yq") ;;
      coreutils) pkgs+=("coreutils") ;;
      nebius) ;; # official installer below
    esac
  done
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    return 0
  fi
  # Do not upgrade already-installed formulae or their dependents.
  export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
  export HOMEBREW_NO_INSTALL_UPGRADE=1
  export NONINTERACTIVE=1
  brew install --formula "${pkgs[@]}"
}

install_nebius() {
  echo "Installing Nebius CLI..."
  curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash
}

install_apt() {
  sudo apt-get update -y
  local pkgs=()
  for name in "${missing[@]}"; do
    case "${name}" in
      jq) pkgs+=("jq") ;;
      kubectl) pkgs+=("kubectl") ;;
      helm) pkgs+=("helm") ;;
      coreutils) pkgs+=("coreutils") ;;
      yq)
        if ! have yq; then
          sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          sudo chmod +x /usr/local/bin/yq
        fi
        ;;
      terraform)
        if have snap; then
          sudo snap install terraform --classic
        else
          echo "Install Terraform from https://developer.hashicorp.com/terraform/install" >&2
          exit 1
        fi
        ;;
      nebius) ;;
    esac
  done
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    sudo apt-get install -y "${pkgs[@]}"
  fi
}

case "${os}" in
  Darwin)
    if ! have brew; then
      echo "Homebrew is required on macOS: https://brew.sh" >&2
      exit 1
    fi
    if [[ " ${missing[*]} " == *" terraform "* ]]; then
      brew tap hashicorp/tap >/dev/null
    fi
    install_brew_pkgs
    if [[ " ${missing[*]} " == *" nebius "* ]]; then
      install_nebius
    fi
    if [[ " ${missing[*]} " == *" coreutils "* ]]; then
      gnubin="$(brew --prefix coreutils)/libexec/gnubin"
      echo
      echo "GNU coreutils installed. Put md5sum on PATH:"
      echo "  export PATH=\"${gnubin}:\$PATH\""
    fi
    ;;
  Linux)
    if have apt-get; then
      install_apt
    elif have brew; then
      install_brew_pkgs
    else
      echo "Install apt or Homebrew, then re-run." >&2
      exit 1
    fi
    if [[ " ${missing[*]} " == *" nebius "* ]]; then
      install_nebius
    fi
    ;;
  *)
    echo "Unsupported OS: ${os}" >&2
    exit 1
    ;;
esac

hash -r 2>/dev/null || true
export PATH="${HOME}/.nebius/bin:${HOME}/.local/bin:${PATH}"

still=()
have terraform || still+=("terraform")
have nebius || still+=("nebius")
have kubectl || still+=("kubectl")
have helm || still+=("helm")
have jq || still+=("jq")
have_yq || still+=("yq")
have_md5sum || still+=("coreutils/md5sum")

if [[ ${#still[@]} -gt 0 ]]; then
  echo "Still missing after install: ${still[*]}" >&2
  echo "Open a new terminal (or exec -l \$SHELL) so PATH picks up Nebius CLI, then re-run." >&2
  exit 1
fi

echo "Prerequisites OK."
echo "Next: nebius profile create   # if not already logged in"
echo "Then: ./scripts/01-seed_tfvars.sh"
