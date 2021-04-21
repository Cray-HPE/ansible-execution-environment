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

## Note on versioning
To increment the version of AEE, the only file that needs to be modified is [.version](.version)

## Note on copyright and license
When making any modifications to a file that has a Cray/HPE copyright header, that header
must be updated to include the current year.

When creating any new files in this repo, if they contain source code, they must have
the HPE copyright and license text in their header, unless the file is covered under
someone else's copyright/license (in which case that should be in the header). For this
purpose, source code files include Docker files, Ansible plays, and shell scripts. It does
**not** include Jenkinsfiles or READMEs.

When in doubt, provided the file is not covered under someone else's copyright or license, then
it does not hurt to add ours to the header.