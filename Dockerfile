#
# MIT License
#
# (C) Copyright 2019-2023 Hewlett Packard Enterprise Development LP
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
FROM artifactory.algol60.net/registry.suse.com/suse/sle15:15.3 as base

# Set the SLES SP number
ARG SP=3
# Pin the version of csm-ssh-keys being installed. The actual version is substituted by
# the runBuildPrep script at build time
ARG CSM_SSH_KEYS_VERSION=@RPM_VERSION@
ARG SOPS_VERSION=3.6.0
ARG SOPS_REBUILD_ID=1
ARG SOPS_RPM_SOURCE=https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}-${SOPS_REBUILD_ID}.x86_64.rpm
ARG COMMUNITY_SOPS_VERSION=1.6.3

# Do zypper operations using a wrapper script, to isolate the necessary artifactory authentication
COPY zypper-docker-build.sh /
# The above script calls the following script, so we need to copy it as well
COPY zypper-refresh-patch-clean.sh /
RUN --mount=type=secret,id=ARTIFACTORY_READONLY_USER --mount=type=secret,id=ARTIFACTORY_READONLY_TOKEN \
    ./zypper-docker-build.sh && \
    rm /zypper-docker-build.sh /zypper-refresh-patch-clean.sh

COPY requirements.txt constraints.txt /
ENV LANG=C.utf8
RUN pip3 install --no-cache-dir -U pip wheel && \
    pip3 install --no-cache-dir -r requirements.txt && \
    find . -iname '/opt/cray/ansible/requirements/*.txt' -exec  pip3 install --no-cache-dir -r "{}" \;

# Stage our runtime configuration
COPY ansible.cfg /etc/ansible/

# Stage our custom plugins
COPY /callback_plugins/*            /usr/share/ansible/plugins/callback/
COPY /strategy_plugins/*            /usr/share/ansible/plugins/strategy/
COPY /modules/*                     /usr/share/ansible/plugins/modules/
RUN mv /opt/cray/ansible/modules/*    /usr/share/ansible/plugins/modules/

# Stage ARA plugins
RUN mkdir -p /usr/share/ansible/plugins/ara/
RUN cp $(python3 -m ara.setup.callback_plugins)/*.py /usr/share/ansible/plugins/ara/

# Add community modules and pre-install necessary binaries to support them from the distro
RUN curl -L --output sops.rpm $SOPS_RPM_SOURCE && rpm -ivh sops.rpm
RUN ansible-galaxy collection install community.sops:$COMMUNITY_SOPS_VERSION

# Stage our default ansible variables
COPY cray_ansible_defaults.yaml /

# Establish runtime Scripts and Entrypoints
COPY entrypoint.sh /
COPY entrypoint-setup.sh /

# Without catatonit, Ansible zombies (possibly 10s of thousands) of ssh processes
ENTRYPOINT ["catatonit", "--", "/entrypoint.sh"]
CMD ["ansible-playbook", "/etc/ansible/site.yml"]
