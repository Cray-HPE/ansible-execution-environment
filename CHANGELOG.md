# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This is the changelog for the configuration framework service (CFS) for its
associated Anisble Execution Environment (AEE). For more information about what
this does, see the README.md entry.

## [Unreleased]
### Dependencies
- Bumped `ansible` from 2.9.13 to 2.9.27
- Bumped `bcrypt` from 3.1.6 to 3.1.7
- Bumped `cffi` from 1.14.3 to 1.14.6
- Bumped `Jinja2` from 2.10.1 to 2.10.3
- Bumped `jmespath` from 0.9.3 to 0.9.5
- Bumped `netaddr` from 0.7.19 to 0.7.20
- Bumped `rsa` from 4.7 to 4.7.2
- Bumped `urllib3` from 1.25.9 to 1.25.11

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
