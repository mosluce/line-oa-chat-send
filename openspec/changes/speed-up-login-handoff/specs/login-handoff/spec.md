## ADDED Requirements

### Requirement: Handoff attaches to an existing browser session

The login handoff SHALL attach to an existing browser session and SHALL NOT start, own, or terminate Chromium or its display.

#### Scenario: Handoff arms against a running session

- **WHEN** a handoff is requested and a browser session is running
- **THEN** the handoff attaches to that session's existing display
- **AND** does not start a second Chromium process

#### Scenario: Handoff requested with no session

- **WHEN** a handoff is requested and no browser session is running or the recorded session state is stale
- **THEN** the handoff exits non-zero
- **AND** reports that a browser session must be started first

#### Scenario: Handoff requested while a browser session is already running

- **WHEN** a handoff is requested while Chromium is running and serving its CDP endpoint
- **THEN** the handoff arms successfully
- **AND** the running browser session continues uninterrupted

### Requirement: Revoking a handoff preserves the browser session

Revoking a handoff SHALL remove external reachability only, leaving Chromium, its display, and its authenticated profile running.

#### Scenario: Explicit revocation

- **WHEN** a handoff is revoked by operator action
- **THEN** the tunnel is stopped and the private route is removed
- **AND** Chromium and its display remain running
- **AND** a subsequent message send against the same session succeeds without a browser restart

#### Scenario: TTL expiry

- **WHEN** the handoff TTL elapses
- **THEN** the handoff is revoked with the same effect as explicit revocation
- **AND** the browser session remains running

#### Scenario: Re-authentication mid-session

- **WHEN** the user needs to re-authenticate and a browser session is already running
- **THEN** a handoff can be armed without first shutting down the browser session

### Requirement: Handoff requires explicit login scope and a bounded lifetime

The handoff SHALL start only under an explicit login purpose and SHALL enforce a bounded time-to-live.

#### Scenario: Missing purpose

- **WHEN** a handoff is requested without the explicit login purpose set
- **THEN** the handoff exits non-zero without creating any external route

#### Scenario: Out-of-range TTL

- **WHEN** a TTL outside the permitted range is supplied
- **THEN** the handoff exits non-zero without creating any external route

#### Scenario: Only one handoff at a time

- **WHEN** a handoff is requested while another handoff is already armed
- **THEN** the request is refused
- **AND** the existing handoff is left intact rather than silently replaced

### Requirement: Only a verified URL is emitted

The handoff SHALL verify that its public URL is externally usable before emitting it, and SHALL emit no URL otherwise.

#### Scenario: Verification succeeds

- **WHEN** the public URL returns HTTP 200 with noVNC content within the verification deadline
- **THEN** the handoff prints exactly one URL
- **AND** the URL is printed only after verification has passed

#### Scenario: Verification fails

- **WHEN** the public URL does not become usable within the verification deadline
- **THEN** the handoff prints no URL
- **AND** revokes everything it started
- **AND** exits non-zero naming the phase that failed

#### Scenario: Verification is performed externally

- **WHEN** the handoff verifies its URL
- **THEN** it requests the public URL rather than only the local listener
- **AND** a successful local request alone is not treated as verification

### Requirement: Handoff records phase timing on every run

The handoff SHALL record the elapsed time of each startup phase on every run, without requiring a debug flag.

#### Scenario: Timing recorded on a successful run

- **WHEN** a handoff arms successfully
- **THEN** it records timestamps for script entry, display attachment, screen-sharing readiness, tunnel URL emission, and public URL verification
- **AND** prints a phase summary alongside the verified URL

#### Scenario: Timing recorded on a failed run

- **WHEN** a handoff fails at any phase
- **THEN** the phases completed before the failure are still recorded and reported
- **AND** the failing phase is identifiable from the output

#### Scenario: Timing data excludes secrets

- **WHEN** timing data is written to the run log
- **THEN** it contains phase names and durations only
- **AND** it does not contain the tunnel URL, the private route token, or any credential

### Requirement: The emitted URL is treated as a bearer secret

The handoff URL SHALL be protected by a high-entropy private route and SHALL NOT be persisted.

#### Scenario: Private route per handoff

- **WHEN** a handoff is armed
- **THEN** a fresh high-entropy route token is generated for that handoff
- **AND** requests that do not match the token route are refused by the front end

#### Scenario: URL is not persisted

- **WHEN** a handoff runs to completion or fails
- **THEN** the emitted URL and its route token are absent from the run log and from any committed file
