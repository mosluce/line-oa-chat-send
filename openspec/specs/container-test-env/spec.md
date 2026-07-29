# container-test-env Specification

## Purpose

A reproducible Linux environment for executing and deliberately breaking this repository's scripts, including its dependency variants, its credential and egress boundaries, and the limits on what its results may be used to conclude.

## Requirements

### Requirement: The container provides the full Linux runtime the scripts expect

The container image SHALL provide every dependency the repository's scripts check for, so that a preflight run inside the container reports a usable environment.

#### Scenario: Full variant satisfies preflight

- **WHEN** the environment preflight is run inside the full container variant
- **THEN** the display server, VNC server, websockify with noVNC assets, HTTP front end, tunnel client, Chromium, and Python runtime with Playwright are all reported usable

#### Scenario: Chromium comes from the distribution

- **WHEN** the image provides Chromium
- **THEN** it uses the distribution's own package rather than a Playwright managed download
- **AND** the Python runtime is provisioned without requiring a browser download

### Requirement: The container runs architecture-native and refuses emulation

The container SHALL run natively on the host architecture and SHALL fail loudly rather than run under emulation.

#### Scenario: Architecture mismatch is detected

- **WHEN** the container starts and its architecture does not match the host architecture
- **THEN** it exits non-zero with a message naming the mismatch
- **AND** does not proceed to run any script

### Requirement: The container is credential-free by construction

The container SHALL NOT be given a real authenticated LINE profile or any credential.

#### Scenario: Throwaway profile only

- **WHEN** a container is started for testing
- **THEN** its Chromium profile is a throwaway profile created for that container
- **AND** no host path containing a real authenticated profile is mounted

#### Scenario: Login page is sufficient for covered behavior

- **WHEN** startup phases, refusal paths, or dependency detection are exercised
- **THEN** they operate against the LINE login page
- **AND** require no authenticated session

#### Scenario: End-to-end send is out of the container's reach

- **WHEN** a successful message send needs verification
- **THEN** that verification is performed on the target host with a real session
- **AND** is not claimed to be covered by the container

### Requirement: Storage mechanism matches the workload

The container SHALL place the browser profile on container-native storage and SHALL mount repository sources read-only.

#### Scenario: Profile on a container volume

- **WHEN** the container runs Chromium
- **THEN** its profile is on a container-native volume rather than a host bind mount

#### Scenario: Sources are read-only

- **WHEN** repository sources are made available inside the container
- **THEN** they are mounted read-only
- **AND** a test run cannot modify the working tree

### Requirement: Environment variants derive from one definition

The image SHALL provide variants that omit specific dependencies, and all variants SHALL derive from a common base so they cannot drift apart.

#### Scenario: Required variants exist

- **WHEN** environment variants are built
- **THEN** a full variant, a variant without the Python/Playwright runtime, a variant without the handoff dependencies, and a variant with a present but unauthenticated profile are all available

#### Scenario: Variants share a base

- **WHEN** a dependency in the base changes
- **THEN** every variant reflects that change without a separate edit

#### Scenario: Variants drive preflight verdicts

- **WHEN** the environment preflight is run in a variant missing a dependency
- **THEN** it reports that dependency as unusable with its documented remediation
- **AND** does not report a different or unrelated failure

### Requirement: Tunnel-creating tests are opt-in

Tests that create a publicly reachable tunnel SHALL NOT run as part of the default test path.

#### Scenario: Default path needs no external egress

- **WHEN** the default test path is run
- **THEN** it completes without creating any externally reachable URL

#### Scenario: Tunnel test is explicit and bounded

- **WHEN** a test that creates a real tunnel is run
- **THEN** it is explicitly opted into
- **AND** its exposure is bounded by the handoff's time-to-live
- **AND** removing the container removes the tunnel

### Requirement: Container results are authoritative only for behavior

Results obtained in the container SHALL be treated as authoritative for behavior and SHALL NOT be treated as authoritative for latency attribution or reported speedup.

#### Scenario: Behavioral results are accepted

- **WHEN** the container exercises refusal paths, error paths, dependency detection and remediation messages, or the arm and revoke lifecycle
- **THEN** those results are accepted as authoritative

#### Scenario: Latency results are not accepted as conclusions

- **WHEN** the container produces phase timings
- **THEN** they are usable for rehearsing the measurement and for same-host before-and-after comparison
- **AND** they are not used to decide which startup phase dominates
- **AND** they are not reported as the change's speedup figure

#### Scenario: Measurement tasks are marked target-host-only

- **WHEN** a task determines phase dominance or reports a final speedup number
- **THEN** it is marked as requiring execution on the target Linux host
