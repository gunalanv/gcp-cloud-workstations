# syntax=docker/dockerfile:1

#
# Copyright 2024 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# NOTE: This dockerfile uses heredoc syntax (indicated in the first line of this
# dockerfile). Ensure you set DOCKER_BUILDKIT=1 when building:
# DOCKER_BUILDKIT=1 docker build -t code-oss-cuttlefish-browselite .

FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss

# Install repo and rsync
RUN apt-get update && apt-get install -y \
  repo \
  rsync && \
  #smoke tests
  repo version && \
  rsync --version

# Install google-chrome
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
  # Note: to harden security profile of this script you could validate the
  # checksum of the package downloaded.
  apt install -y ./google-chrome*.deb && \
  rm google-chrome*.deb

# Install browselite plugin
RUN VERSION=0.3.9 && \
  wget https://open-vsx.org/api/antfu/browse-lite/$VERSION/file/antfu.browse-lite-$VERSION.vsix && \
  # Note: to harden security profile of this script you could validate the
  # checksum of the package downloaded.
  unzip antfu.browse-lite-$VERSION.vsix "extension/*" && \
  mv extension /opt/code-oss/extensions/antfu.browse-lite && \
  rm antfu.browse-lite-$VERSION.vsix

# Add a startup script to configure browselite to point to our chrome installation.
RUN cat >> /etc/workstation-startup.d/210_configure_browselite.sh <<-EOF
if [[ "\${EUID:-\$(id -u)}" -eq 0 ]]; then
    exec runuser user "\${BASH_SOURCE[0]}"
fi
echo "Configuring browse-lite"
settings_file="/home/user/.codeoss-cloudworkstations/data/Machine/settings.json"
if [[ ! -f \${settings_file} ]]; then
    mkdir -p /home/user/.codeoss-cloudworkstations/data/Machine/
    echo "{}" > \${settings_file}
fi
if [[ ! \$(grep "browse-lite.chromeExecutable" "\${settings_file}") ]]; then
    jq '{"browse-lite.chromeExecutable": "/usr/bin/google-chrome"} + .' \${settings_file} > \${settings_file}.tmp
    mv \${settings_file}.tmp \${settings_file}
fi
EOF

RUN chmod 755 /etc/workstation-startup.d/210_configure_browselite.sh

ENTRYPOINT ["/google/scripts/entrypoint.sh"]
