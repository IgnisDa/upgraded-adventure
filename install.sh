#!/bin/bash
set -e

set -a
. ./devcontainer-features.env
set +a

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

if [[ -n "${_BUILD_ARG_FISH}" ]]; then

    USERNAME=${_BUILD_ARG_FISH_USERNAME:-"automatic"}

    # Determine the appropriate non-root user
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        USERNAME=""
        POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
        for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
            if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
                USERNAME=${CURRENT_USER}
                break
            fi
        done
        if [ "${USERNAME}" = "" ]; then
            USERNAME=root
        fi
    elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
        USERNAME=root
    fi

    export DEBIAN_FRONTEND=noninteractive

    # Install fish shell
    echo "Installing fish shell..."
    if grep -q 'Ubuntu' < /etc/os-release; then
        apt-get -y install --no-install-recommends software-properties-common
        apt-add-repository ppa:fish-shell/release-3
        apt-get update
        apt-get -y install --no-install-recommends fish
        apt-get autoremove -y
    elif grep -q 'Debian' < /etc/os-release; then
        if grep -q 'stretch' < /etc/os-release; then
            echo 'deb http://download.opensuse.org/repositories/shells:/fish/Debian_9.0/ /' | tee /etc/apt/sources.list.d/shells:fish.list
            curl -fsSL https://download.opensuse.org/repositories/shells:fish/Debian_9.0/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/shells_fish.gpg > /dev/null
        elif grep -q 'buster' < /etc/os-release; then
            echo 'deb http://download.opensuse.org/repositories/shells:/fish/Debian_10/ /' | tee /etc/apt/sources.list.d/shells:fish.list
            curl -fsSL https://download.opensuse.org/repositories/shells:fish/Debian_10/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/shells_fish.gpg > /dev/null
        elif grep -q 'bullseye' < /etc/os-release; then
            echo 'deb http://download.opensuse.org/repositories/shells:/fish/Debian_11/ /' | tee /etc/apt/sources.list.d/shells:fish.list
            curl -fsSL https://download.opensuse.org/repositories/shells:fish/Debian_11/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/shells_fish.gpg > /dev/null
        fi
        apt update
        apt install -y fish
        apt autoremove -y
    fi

    if [ "${_BUILD_ARG_FISH_FISHER}" = "true" ]; then
        # Install Fisher
        echo "Installing Fisher..."
        fish -c 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher'
        if [ "${USERNAME}" != "root" ]; then
            sudo -u "$USERNAME" fish -c 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher'
        fi
    fi

elif [[ -n "${_BUILD_ARG_VOLTA}" ]]; then
    curl https://get.volta.sh | bash
    update() {
        echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
        if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/bash.bashrc
        fi
        if [ -f "/etc/zsh/zshrc" ] && [[ "$(cat /etc/zsh/zshrc)" != *"$1"* ]]; then
            echo -e "$1" >> /etc/zsh/zshrc
        fi
    }
    update "$(cat << EOF
    export PATH="/root/.volta/bin:\${PATH}"
EOF
)"
fi

echo "Done!"
