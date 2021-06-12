FROM oraclelinux:8

RUN echo '[ol8_developer_EPEL]' >> /etc/yum.repos.d/ol8-epel.repo && \
    echo 'name= Oracle Linux $releasever EPEL ($basearch)' >> /etc/yum.repos.d/ol8-epel.repo && \
    echo 'baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/developer/EPEL/$basearch/' >> /etc/yum.repos.d/ol8-epel.repo && \
    echo -e "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle\ngpgcheck=1\nenabled=1\n" >> /etc/yum.repos.d/ol8-epel.repo


RUN dnf makecache -y && dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN dnf makecache -y && dnf install -y git curl wget rsync python3 python3-pip python3-virtualenv

WORKDIR /app
COPY dist/ /app/dist/
COPY dotfiles/ /app/dotfiles/
COPY extras/ /app/extras/
COPY omz_themes/ /app/omz_themes/
COPY scripts/ /app/scripts/
COPY zsh_files/ /app/zsh_files/
COPY core.sh lib.sh /app/


CMD [ "bash" ]

