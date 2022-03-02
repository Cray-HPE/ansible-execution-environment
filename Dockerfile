# Copyright 2019-2021 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# (MIT License)

FROM artifactory.algol60.net/registry.suse.com/suse/sle15:15.3 as base

# Pin the version of csm-ssh-keys being installed. The actual version is substituted by
# the runBuildPrep script at build time
ARG CSM_SSH_KEYS_VERSION=@RPM_VERSION@

RUN zypper ar --no-gpgcheck https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp2/ hpe-csm-stable && zypper --non-interactive refresh
RUN zypper in --no-confirm python3-devel python3-pip gcc libopenssl-devel openssh curl less catatonit rsync glibc-locale-base 

RUN zypper in -f --no-confirm csm-ssh-keys-@RPM_VERSION@
# And lock the version, just to be certain it is not upgraded inadvertently by some later
# zypper command
RUN zypper al csm-ssh-keys

# Apply security patches
COPY zypper-refresh-patch-clean.sh /
RUN /zypper-refresh-patch-clean.sh && rm /zypper-refresh-patch-clean.sh

COPY requirements.txt constraints.txt /
ENV LANG=C.utf8
RUN PIP_INDEX_URL=https://arti.dev.cray.com:443/artifactory/api/pypi/pypi-remote/simple \
    pip3 install --no-cache-dir -U pip wheel && \
    pip3 install --no-cache-dir -r requirements.txt && \
    find . -iname '/opt/cray/ansible/requirements/*.txt' -exec  pip3 install --no-cache-dir -r "{}" \;

# Stage our runtime configuration
COPY ansible.cfg /etc/ansible/

# Stage our custom plugins
COPY /callback_plugins/*            /usr/share/ansible/plugins/callback/
COPY /strategy_plugins/*            /usr/share/ansible/plugins/strategy/
COPY /modules/*                     /usr/share/ansible/plugins/modules/
RUN mv /opt/cray/ansible/modules/*    /usr/share/ansible/plugins/modules/

# Stage our default ansible variables
COPY cray_ansible_defaults.yaml /

# Establish runtime Scripts and Entrypoints
COPY entrypoint.sh /
COPY entrypoint-setup.sh /

# Without catatonit, Ansible zombies (possibly 10s of thousands) of ssh processes
ENTRYPOINT ["catatonit", "--", "/entrypoint.sh"]
CMD ["ansible-playbook", "/etc/ansible/site.yml"]
