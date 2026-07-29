# browser-session Specification

## Purpose

Lifecycle of the long-lived headed Chromium, its private X display, its loopback-only screen-sharing stack, and its loopback CDP endpoint — start, readiness, and graceful shutdown, independent of any handoff.

## Requirements

### Requirement: Browser session owns a durable display

The browser session SHALL own a headed Chromium process together with the X display it runs on, and both SHALL outlive any individual login handoff.

#### Scenario: Session starts its own display

- **WHEN** a browser session is started and no `DISPLAY` is provided
- **THEN** the session creates a private X display, waits until that display accepts connections, and starts Chromium on it
- **AND** the display is not torn down when a handoff is revoked

#### Scenario: Display readiness is verified, not assumed

- **WHEN** the session starts an X display
- **THEN** it polls for the display to become connectable before starting Chromium
- **AND** it does not rely on a fixed sleep or on a process-liveness check alone
- **AND** it fails with a named error if the display does not become connectable within its deadline

### Requirement: Browser session publishes discoverable state

The browser session SHALL record its display, Chromium profile directory, and CDP endpoint in a state file inside the private runtime directory so that other components can attach without guessing.

#### Scenario: State is written on successful start

- **WHEN** Chromium becomes reachable on its loopback CDP endpoint
- **THEN** the session writes a state file recording the display, profile directory, and CDP endpoint
- **AND** the state file is created inside the private runtime directory with restrictive permissions

#### Scenario: Stale state is detected

- **WHEN** a state file exists but the recorded display or CDP endpoint does not respond
- **THEN** any component reading the state treats the session as absent
- **AND** reports that a browser session must be started, rather than attaching to a dead display

### Requirement: Browser session runs a loopback-only screen-sharing stack

The browser session SHALL run its screen-sharing components bound to loopback only, so that no external route to the browser exists unless a handoff tunnel is running.

#### Scenario: Screen sharing is reachable only from loopback

- **WHEN** a browser session is running without an armed handoff
- **THEN** the VNC server, the websockify bridge, and the HTTP front end are all bound to loopback
- **AND** no externally reachable route to the browser exists

#### Scenario: Ports are selected dynamically

- **WHEN** the session starts its screen-sharing components
- **THEN** it selects a free loopback port for each component rather than assuming a fixed port
- **AND** it does not discard the components' output, so that a bind failure is reported rather than surfacing later as a blank remote canvas

### Requirement: Browser session refuses to duplicate itself

The browser session SHALL NOT start a second Chromium against a profile that an existing session is already using.

#### Scenario: Session already running

- **WHEN** a browser session start is requested and the configured CDP endpoint already responds
- **THEN** the start fails with an instruction to reuse the existing session
- **AND** no component of the existing session is modified or terminated

### Requirement: Browser session has a scripted shutdown

The browser session SHALL provide a scripted graceful shutdown that terminates the session it owns while preserving the persistent Chromium profile.

#### Scenario: Graceful shutdown

- **WHEN** a session shutdown is requested
- **THEN** the session identifies its own Chromium root process through its recorded state rather than a broad process-name pattern
- **AND** sends a graceful termination signal and waits for exit
- **AND** stops the display and loopback screen-sharing components it started
- **AND** leaves the persistent Chromium profile directory unmodified

#### Scenario: Shutdown while a handoff is armed

- **WHEN** a session shutdown is requested while a handoff is armed
- **THEN** the shutdown revokes the handoff first
- **AND** does not leave a tunnel running against a terminated browser

#### Scenario: Process does not exit gracefully

- **WHEN** the Chromium root process has not exited within the graceful timeout
- **THEN** the shutdown reports the blocker and exits non-zero
- **AND** does not escalate to a forced kill on its own
