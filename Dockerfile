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

FROM dtr.dev.cray.com/baseos/sles15sp2:sles15sp2

RUN zypper ar --no-gpgcheck http://car.dev.cray.com/artifactory/csm/SCMS/sle15_sp2_ncn/x86_64/release/shasta-1.4/ sles15_sp2_ncn && zypper refresh
RUN zypper in --no-confirm python3-devel python3-pip gcc libopenssl-devel openssh curl less catatonit rsync glibc-locale-base csm-ssh-keys

COPY requirements.txt constraints.txt /
ENV LANG=C.utf8
RUN PIP_INDEX_URL=https://arti.dev.cray.com:443/artifactory/api/pypi/pypi-remote/simple \
    pip install --no-cache-dir -U pip wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    find . -iname '/opt/cray/ansible/requirements/*.txt' -exec  pip install --no-cache-dir -r "{}" \;


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
