# Ansible Execution Environment
This is the Ansible Execution Environment (AEE). It is primarily used as an execution
agent in concert with the Configuration Framework Service (CFS).

The initial design document for this project is viewable here:
https://connect.us.cray.com/confluence/display/SCMS/Shasta+Configuration+Management+Design

More specifically, this environment is an integral role in both Image Customization
and Node Personalization. From AEE's perspective, the functional difference
between these use cases is are the effective configuration targets.

In all cases, AEE honors group_vars and host_vars settings that are populated to
the inventory directory. This should be used as the shared mount point for
providing configuration overrides for configuring and provisioning inventory
members (either images or nodes).

## Build Helpers
This repo uses some build helper scripts from the 
[cms-meta-tools](https://github.com/Cray-HPE/cms-meta-tools) repo. See that repo for more details.

## Local Builds
If you wish to perform a local build, you will first need to clone or copy the contents of the
cms-meta-tools repo to `./cms_meta_tools` in the same directory as the `Makefile`.

## Versioning
We use [SemVer](http://semver.org/). The version is generated by the version.py script in the
cms-meta-tools repo, and written to the .version file at build time by 
[Jenkinsfile.github](Jenkinsfile.github). It also generates the Docker version and Chart version
 strings, and writes those to .docker_version and .chart_version respectively.

In order to make it easier to go from a version number back to the source code that produced that version,
a text file named gitInfo.txt is added to Docker images and RPMs build from this repo. For Docker images,
it can be found in the /app folder. For RPMs, it is installed on the system under the 
/opt/cray/.rpm_info/*rpm_name*/*version*/*release* directory. This file contains the branch from which
it was built and the most recent commits to that branch. In addition, a few annotation metadata fields
containing similar information are added to the k8s chart.

## Copyright and License
This project is copyrighted by Hewlett Packard Enterprise Development LP and is under the MIT
license. See the [LICENSE](LICENSE) file for details.

When making any modifications to a file that has a Cray/HPE copyright header, that header
must be updated to include the current year.

When creating any new files in this repo, if they contain source code, they must have
the HPE copyright and license text in their header, unless the file is covered under
someone else's copyright/license (in which case that should be in the header). For this
purpose, source code files include Dockerfiles, Ansible files, and shell scripts. It does
**not** include Jenkinsfiles or READMEs.

When in doubt, provided the file is not covered under someone else's copyright or license, then
it does not hurt to add ours to the header.