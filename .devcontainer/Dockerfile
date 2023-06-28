FROM fedora:38

COPY resources/sudoers.d/vscode.conf /etc/sudoers.d/vscode

RUN dnf install -y ncurses \
    git \
    && curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash -s -- -a

RUN useradd -G wheel -ms /bin/bash vscode
