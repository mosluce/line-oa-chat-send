# environment-preflight Specification

## Purpose

A scripted check that reports whether the runtime, browser, display, and handoff dependencies are usable, and distinguishes a missing LINE login from a broken environment.

## Requirements

### Requirement: Preflight is a single scripted check

The environment preflight SHALL be performed by one script that reports a verdict, replacing the prose procedure in `SKILL.md`.

#### Scenario: Single command reports overall readiness

- **WHEN** the preflight script is run
- **THEN** it reports each checked component as usable or not usable
- **AND** exits zero only when the environment can perform a message send

#### Scenario: SKILL.md defers to the script

- **WHEN** `SKILL.md` describes environment preparation
- **THEN** it names the preflight command and explains what its failure verdicts mean
- **AND** does not restate the individual checks as steps

### Requirement: Preflight checks capability, not command presence

Each check SHALL assert that the component actually works, not merely that a command exists on `PATH`.

#### Scenario: Python runtime check

- **WHEN** the preflight checks the Python runtime
- **THEN** it confirms that the selected interpreter can import Playwright
- **AND** does not treat the presence of a `python3` binary as sufficient

#### Scenario: Browser and profile check

- **WHEN** the preflight checks the browser and profile
- **THEN** it confirms the Chromium executable is executable and the profile directory is a readable and writable directory

#### Scenario: CDP check

- **WHEN** the preflight checks the CDP endpoint
- **THEN** it confirms the endpoint responds
- **AND** does not infer reachability from a running process

### Requirement: An unauthenticated session is a distinct verdict

The preflight SHALL distinguish a missing or expired LINE login from a broken environment.

#### Scenario: Environment ready but not authenticated

- **WHEN** the runtime, browser, display, and CDP endpoint are all usable but the LINE session is absent or expired
- **THEN** the preflight reports that user authentication is required through the login handoff
- **AND** does not report the environment as broken or the installation as failed

### Requirement: Preflight reports actionable remediation without privileged action

For each failing check the preflight SHALL report a concrete remediation, and SHALL NOT perform privileged installation itself.

#### Scenario: Missing runtime

- **WHEN** no Python runtime with Playwright is available
- **THEN** the preflight names the setup command and the environment variable to export afterwards

#### Scenario: Missing host dependency

- **WHEN** a handoff dependency such as the display server, VNC, websockify, HTTP front end, or tunnel client is missing
- **THEN** the preflight names the exact missing commands and prints installation instructions for an operator with host package permission
- **AND** does not invoke `sudo` or a system package manager itself

#### Scenario: Network bindings are never weakened

- **WHEN** the preflight reports any remediation
- **THEN** no suggested action widens a loopback binding or exposes CDP, VNC, or the browser profile to the network
