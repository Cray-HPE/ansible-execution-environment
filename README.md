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

