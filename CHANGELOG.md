# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This is the changelog for the configuration framework service (CFS) for its
associated Anisble Execution Environment (AEE). For more information about what
this does, see the README.md entry.

## [Unreleased]
### Removed
- Deprecated Vault login token acquisition steps from init script
### Dependencies
- CSM 1.6 moved to Kubernetes 1.24, so use client v24.x to ensure compatability

## [1.17.1] - 2024-08-23

### Changed
- Add code to avoid curl versions due to a [known bug with that version](https://github.com/curl/curl/issues/13229)

## [1.17.0] - 2024-08-22

### Dependencies
- Move Docker image to SLES15 SP6
- Move to Python 3.11 inside Docker image
- Bump `cffi` and `PyYAML` version requirements to accomodate move to Python 3.11

## [1.16.4] - 2024-08-08

### Changed
- List Python packages after installing, for build log purposes

### Dependencies
- Bump SOPS version from 3.6.0 to 3.6.1.
- Bump Community SOPS version from 1.6.3 to 1.6.6.
- Pin major/minor versions for Python packages, but use latest patch version

## [1.16.3] - 2024-07-24
### Dependencies
- Bump `certifi` from 2019.11.28 to 2023.7.22 to resolve CVE

## [1.16.3] - 2024-08-12
### Added
- Automatically fetch and set vault token before ansible executes

## [1.16.2] - 2024-03-20
### Fixed
- Fixed loading kubernetes configuration data in the shasta_s3_creds module

## [1.16.1] - 2024-02-22
### Dependencies
- Bumped `csm-ssh-keys` from 1.5 to 1.6 for CSM 1.6

## [1.16.0] - 2024-02-22
### Dependencies
- Bumped `kubernetes` from 11.0.0 to 22.6.0 to match CSM 1.6 Kubernetes version
- Bumping `kubernetes` necessitated bumping `openshift` from 0.11.2 to 0.13.2

## [1.15.3] - 2023-10-26
### Added
- aws_s3 ansible galaxy collection for s3 projection
### Changed
- Updated the formatting of ansible-modules into a single alphabetical invocation.

## [1.15.2] - 2023-10-24
### Added
- Added ansible.netcommon module for UAN use

## [1.15.1] - 2023-09-27
### Added
- Tuneables for SOPS that support use of vars collection and hashicorp vault
- Reintroduced the community.general package to support zypper operations
- Adds community.hashivault
- Adds kubernetes community modules
- Added a number of missing, common, or likely to be used modules in the shasta ecosystem.
### Changed
- Migrated to ansible-core instead of ansible package
- Upgraded from ansible 2.9.27 to 2.11.12


## [1.14.0] - 2023-08-18
### Added
- Infrastructure required to do community installs of ansible modules for SOPS
- Added support for DEBUG_WAIT_TIME
- Added support for special debug playbooks
- Added session label for ara recording

### Changed
- Disabled concurrent Jenkins builds on same branch/commit
- Added build timeout to avoid hung builds
- Moved to the v3 CFS api

### Dependencies
Bumped dependency patch versions:
| Package                  | From    | To       |
|--------------------------|---------|----------|
| `ansible`                | 2.9.13  | 2.9.27   |
| `bcrypt`                 | 3.1.6   | 3.1.7    |
| `cffi`                   | 1.14.3  | 1.14.6   |
| `Jinja2`                 | 2.10.1  | 2.10.3   |
| `jmespath`               | 0.9.3   | 0.9.5    |
| `netaddr`                | 0.7.19  | 0.7.20   |
| `rsa`                    | 4.7     | 4.7.2    |
| `urllib3`                | 1.25.9  | 1.25.11  |

## [1.4.4] - 2023-08-14
### Changed
- CASMCMS-8691: Add CSM `noos` Zypper repository when building Docker image to account for new RPM locations

## [1.4.3] - 2023-07-20
### Dependencies
- CASMCMS-8717: Bump `paramiko` from 2.4.2 to 2.7.2 and `cryptography` from `cryptography` from 3.2 to 41.0.2
  to fix [Improper Certificate Validation CVE](https://security.snyk.io/vuln/SNYK-PYTHON-CRYPTOGRAPHY-5777683).
  In order to allow this, moved Docker image from Python 3.6 to 3.9.

## [1.4.2] - 2023-03-17
### Changed
- CASMCMS-8471: Use artifactory authentication instead of building from unauthenticated artifactory mirrors

## [1.4.1] - 2023-03-14
### Changed
- Use csm-ssh-keys version 1.5 (CASMCMS-8462)
- Use artifactory mirror in Dockerfile to avoid authentication errors (CASMCMS-8464)

### Removed
- Removed vestigial files from former dynamic versioning system (CASMCMS-8462)

## [1.4.0] - 2023-01-13
### Added
- Added the ARA plugin
- Added playbook information to the ansible container logs

### Changed
- Spelling corrections.
- Changed entrypoint and callback to support multiple playbooks in one container

## [1.2.84] - 2022-12-20
### Added
- Initial migration to gitflow versoining.
