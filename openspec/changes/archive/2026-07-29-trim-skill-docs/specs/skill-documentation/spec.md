## ADDED Requirements

### Requirement: SKILL.md contains decision knowledge and a command surface only

`SKILL.md` SHALL contain what an agent needs in order to decide and act: when the skill applies, the security boundary, a command-level quick start, and the conditions that require stopping and asking the user. It SHALL NOT contain step-by-step procedures that a script performs, nor material needed only when debugging or when developing the repository.

#### Scenario: Deterministic procedure is not restated as prose

- **WHEN** a procedure is fully performed by a script
- **THEN** `SKILL.md` names the command and describes what its failure means
- **AND** does not restate the script's internal steps

#### Scenario: Repository development process is not present

- **WHEN** an agent reads `SKILL.md` in order to send a message
- **THEN** the document contains no branch, pull request, merge, or repository-publication process
- **AND** that material is available in `CONTRIBUTING.md`

### Requirement: The security boundary is preserved in full

The security boundary SHALL remain in `SKILL.md` in full and SHALL NOT be shortened, summarized, or relocated to a reference file.

#### Scenario: Boundary survives restructuring

- **WHEN** `SKILL.md` is restructured
- **THEN** every constraint stated in the previous security boundary is still present in `SKILL.md`
- **AND** the handoff is still described as granting interactive control and as a high-risk bearer secret

### Requirement: Run-time decision rules are stated in SKILL.md

Rules that constrain agent behavior during a run SHALL be stated in `SKILL.md` rather than moved to reference material.

#### Scenario: Ambiguity requires stopping

- **WHEN** a recipient search matches more than one distinct chat
- **THEN** `SKILL.md` directs the agent to stop and ask the user which conversation to use

#### Scenario: Failed post-send verification is not retried

- **WHEN** post-send verification fails
- **THEN** `SKILL.md` directs the agent not to retry before the browser is inspected, because the message may already have been accepted

#### Scenario: Credentials are never handled

- **WHEN** LINE requests a password, QR confirmation, MFA, OTP, or another challenge
- **THEN** `SKILL.md` directs the agent not to request, read, type, store, relay, or log any credential or verification code

### Requirement: Every documentation link resolves

All links in published documentation SHALL resolve to files present in the published package.

#### Scenario: Referenced files exist

- **WHEN** the repository is packaged and published
- **THEN** every relative link in `SKILL.md` and `README.md` resolves to an existing file

#### Scenario: Reference directory is populated

- **WHEN** `SKILL.md` points to reference material
- **THEN** `references/line-oa-ui-selectors.md`, `references/handoff-operations.md`, and `references/public-repository-checklist.md` all exist

### Requirement: There is exactly one implementation of the send flow

Documentation SHALL NOT contain a second implementation of the message-send flow.

#### Scenario: Inline implementation removed

- **WHEN** an agent looks for how the send flow works
- **THEN** `scripts/send_line_oa_chat.py` is the only implementation present in the repository
- **AND** no document contains a runnable alternative that omits the unique-match check, the composer-cleared check, or the transcript verification

#### Scenario: Selector reasoning is documented without restating the algorithm

- **WHEN** a reader needs to understand the DOM patterns the send flow relies on
- **THEN** `references/line-oa-ui-selectors.md` documents the selectors and the reasoning behind them
- **AND** does not duplicate the send algorithm

### Requirement: SKILL.md and README.md describe the same command surface

`SKILL.md` and `README.md` SHALL name the same scripts with the same flags and SHALL NOT restate each other's procedures.

#### Scenario: Command surface agrees

- **WHEN** both documents describe how to run the tool
- **THEN** the script names and flags are identical in both
- **AND** neither describes an operator sequence that the scripts no longer implement
