# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This is the changelog for the configuration framework service (CFS) for its
associated Anisble Execution Environment (AEE). For more information about what
this does, see the README.md entry.

## [Unreleased]
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
