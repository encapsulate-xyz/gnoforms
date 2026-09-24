# gno.land — Mainnet Validator Technical & Security Review (Step 2)
# DRAFT ANSWERS — review before entering. Nothing has been submitted.
#
# The attestation requires: "The answers describe the setup as it actually is
# today; anything planned is labelled as planned." Every forward-looking claim
# below is marked PLANNED on purpose. Do not remove those labels.
#
# ‹FILL› = only you know it.  ‹CONFIRM› = I inferred it; check before sending.

================================================================================
PAGE 2 — 1. APPLICANT
================================================================================

Validator moniker
    Encapsulate

Legal name of entity/individual from Step 1 KYC
    ‹FILL — must match Step 1 exactly›

Email used for Step 1 legal review
    ‹FILL — the address you emailed Carolyn from›

Primary technical contact: name and role
    ‹FILL — e.g. "Aditya Verma, Founder / Infrastructure"›

Secondary technical contact: name and role
    ‹FILL — must be a DIFFERENT human who can act alone in an incident.
     Kowshik Vajrala appears throughout gnoland-ansible's commit history —
     if he is on-call, name him and his role. "none" is a finding, not a fail.›

Discord handle(s) of your operators
    kingsuper, kowshikvajrala

Valoper (operator) address
    g1p8uxq4ska2psv2k8wknljh568k5qfnwtene2qp
    (Ledger-backed, BIP44 m/44'/118'/0'/0/0)

Validator consensus public key
    gpub1pggj7ard9eg82cjtv4u52epjx56nzwgjyg9zpx4pan4zkfxx84uuf0h6jr4cvxvmfad37mnhvl3l5hz8acwtxfn6e57tkl

Have you registered a valoper profile in r/gnops/valopers?
    → Not yet
    (Registered on pearl-1 as "Encapsulate", operator
     g1eyr3hfdcup4rr5xlcd63vc5t64a03u9kecx2v0. Not yet on mainnet: the operator
     address holds no GNOT and there is no faucet — see VALIDATOR.md's open
     TODO on funding post-genesis operators. Mention this in "anything else".)

================================================================================
PAGE 3 — 2. VALIDATOR DEPLOYMENT
================================================================================

Where does the validator node run?
    → Colocation / own hardware in a third-party data centre
    ‹CONFIRM — DigitalOcean physical machines under a custom hardware
     arrangement. If DO bills it as rented bare metal, pick "Bare metal rented
     from a hosting provider" instead.›

Provider(s) and region(s) for validator and each sentry
    ‹CONFIRM + FILL — template:
     "Validator: DigitalOcean physical hardware, Bangalore, India.
      Sentry 1: ‹provider, region›. Sentry 2: ‹provider, region›.
      We also run AWS capacity for provider diversification."
     The form wants at least two providers AND regions for full marks.›

Sentry node architecture
    ‹CONFIRM — pick honestly:
       "2+ sentries, on at least two different providers AND regions"  ← best
       "2+ sentries, same provider or same region"
       "Exactly 1 sentry"
       "No sentry"
     Your committed gnoland-ansible inventory lists ONE host of type
     "validator" and no sentries. If sentries are not up for gno.land yet,
     answer honestly and label the target as PLANNED.›

Hardware specification (validator host, and a typical sentry)
    ‹FILL — they want: CPU cores + model class, RAM, disk size/type/growable,
     network bandwidth, and whether CPU/disk are dedicated or burstable.
     Known: every server is >=1 Gbps duplex, 25 Gbps where needed; dedicated
     hardware per validator. NOTE their storage warning: gno.land nodes are
     archive nodes with no efficient pruning — plan 512 GB+ and growing.›

Validator <-> sentry topology
    The validator peers only with our own sentries: persistent_peers lists the
    sentries and pex is disabled on the validator. Each sentry sets
    private_peer_ids to the validator so it is never gossiped to the wider p2p
    network. The validator advertises no external_address.
    Operator and inter-node management traffic runs over a private Tailscale
    network; the validator's only public-facing surface is p2p to its sentries.
    ‹CONFIRM the Tailscale detail and whether sentry<->validator p2p rides the
     private network or is public with an allowlist.›

Is the validator's RPC (26657) reachable from the public internet?
    → No, reachable only over VPN or from an allowlisted management network
    ‹CONFIRM — if RPC binds to localhost only, pick the first option instead.
     Note: you list public RPC/snapshots as a planned contribution. Those must
     run on separate hosts, never the validator.›

Which ports are open to the public internet, and to whom?
    p2p 26656: sentries only, enforced by UFW rules applied per node type from
    version-controlled vars. RPC 26657 and all management ports: not public,
    reachable only over our private network. No other inbound.
    ‹CONFIRM against roles/node/vars/ufw_rules.yml›

How is infrastructure provisioned and configured?
    ☑ Ansible / Salt / Chef / Puppet
    ☑ Custom scripts in version control

If you use IaC, where does it live and who can merge?
    Ansible, public at github.com/encapsulate-xyz/gnoland-ansible. Playbooks run
    only from a central Semaphore server — never from an engineer's laptop — so
    every deployment is logged, approved and traceable. Secrets are pulled from
    HashiCorp Vault at run time and never stored in the repo or in any image.
    ‹CONFIRM the merge/review policy: is PR review required on main?›

Is the gno.land validator isolated from your other networks?
    ‹CONFIRM — "Yes: dedicated hosts, dedicated network, dedicated credentials"
     is only true if gno.land runs on its own host with its own Vault path and
     its own UFW/network segment. Vault paths are per-project
     (testnet/gnoland/encapsulate/validator/...), which supports "dedicated
     credentials". Choose "Partially" and explain if hosts are shared.›

Anything to add about isolation / multi-tenancy
    Secrets are namespaced per environment, project and organisation in Vault
    (<env>/gnoland/encapsulate/validator/<file>), so gno.land credentials are
    not reachable from another network's automation.

How do you provision, sync and restore a node?
    Provisioning is a single Ansible run: hardened base image, dedicated
    gnoland service user with isolated home/data/log directories, UFW rules per
    node type, binary built from the pinned chain tag, config templated per
    network, seeds and peers version-controlled per environment.
    Restore uses a snapshot-sync playbook rather than syncing from genesis.
    ‹FILL — storage headroom (they expect 512 GB+ and growing), snapshot
     frequency and retention, and measured restore time.›

How do you build, verify and roll out the gnoland binary?
    Built from source at the pinned chain tag (currently chain/pearl on
    testnet), not a downloaded artefact, so the version is pinned in the
    playbook and tracked in git rather than trusted from a release page.
    Upgrades use a coordinated-upgrade playbook that polls chain height and
    holds until the agreed upgrade height before switching binaries.
    ‹CONFIRM — do you verify a checksum/signature on the source tarball or Go
     module deps? Do you roll sentries first? Say so if yes; if not, say not.›

================================================================================
PAGE 4 — 3. CONSENSUS KEY PROTECTION
================================================================================

*** THE MOST SCRUTINISED ANSWER ON THE FORM. Two honest versions below —
*** pick the one that is true on the day you submit.

--- VERSION A: if Horcrux is live for gno.land ---
    The consensus key never exists whole on the validator host. We run Horcrux
    threshold signing: ‹FILL n› cosigners with a ‹FILL k›-of-‹n› threshold, on
    ‹FILL — which hosts and providers›, running Horcrux ‹FILL version›. Each
    cosigner holds only its share; the cluster shares last-signed state, which
    makes double-signing structurally impossible rather than procedurally
    avoided. Cosigner P2P and the Raft control plane are reachable only inside
    our private network — ‹FILL: allowlist / VPN / mTLS› — and are not exposed
    to the validator's public interface. If a validator host were compromised,
    it could request signatures but could not extract key material, and the
    HRS gate would still refuse a conflicting height.
    gno.land supports this through its tmkms listener mode: the validator
    listens and each cosigner dials in against allowed_kms_pubkeys.

--- VERSION B: if it is still local-file signing (TRUE TODAY) ---
    Today (PLANNED to change before mainnet signing begins): the mainnet
    consensus key was generated with `gnoland secrets init` and is held in our
    HashiCorp Vault cluster (4-of-7 unseal threshold, sealed by default). Our
    Ansible playbook places priv_validator_key.json on the validator at deploy
    time, owned by the dedicated gnoland service user with 0600 permissions on
    an encrypted volume; no other account on the host can read it.
    PLANNED before we sign on mainnet: move to Horcrux threshold signing via
    gno.land's tmkms listener mode, so the whole key never lands on the
    validator. ‹FILL target date›.

    ‹DECIDE — our public gnoland-ansible does local-file signing today. The
     review team can read that repo; it is linked from our valoper profile.
     Claiming Horcrux while the repo shows otherwise is the one thing on this
     form that could cost real credibility.›

Consensus key backup: select everything true
    ☑ A backup exists
    ☑ The backup is encrypted
    ☑ The backup is stored off the validator server
    ☑ The backup is in a different physical location from the validator
    ‹CONFIRM: "offline / air-gapped"? "split (Shamir, multi-custody)"?
     Vault is off-host and encrypted but is not air-gapped. Tick only what is
     true. Redundancy of 3, AES-256 at rest is your stated policy.›

Describe the backup and restore procedure, and who can authorise one
    Key material is stored with a redundancy of 3 and encrypted with AES-256
    before it reaches any backup store. Retrieval requires unsealing our Vault
    cluster, which needs 4 of 7 unseal key holders; Vault stays sealed by
    default and is unsealed only for the duration of a push or retrieval.
    Human access is by short-lived Vault-issued SSH certificates with a 1-hour
    TTL, so a departing operator loses access when their certificate expires
    rather than when someone remembers to remove a key.
    ‹FILL — which roles may authorise a retrieval, the offboarding step that
     removes an unseal-key holder, and WHEN YOU LAST TESTED A RESTORE. They
     ask that explicitly; "never" is worse than a date.›

================================================================================
PAGE 5 — 4. DOUBLE-SIGN PREVENTION
================================================================================

Redundancy model
    ‹CONFIRM — if Horcrux: "Multiple signers coordinated by a remote signer /
     threshold signer". If not yet: your documented model is a secondary node
     in a different data centre and geography running as a full node or with
     dummy keys, i.e. "Cold standby: a second host exists, the consensus key is
     NOT on it".›

Can the consensus key be present on two running nodes at once?
    ‹CONFIRM — with Horcrux: "No, never: structurally impossible in our setup".
     With cold standby + destroy-confirmation: "Yes, but signing is gated by a
     lock, a signer, or a manual step".›

Describe your failover procedure step by step
    1. An alert fires (Prometheus rule breach) and pages on-call via PagerDuty.
       On-call acknowledges and attempts an in-place fix first.
    2. If the host itself is unreachable, we contact the data centre for status
       rather than assuming the node is dead.
    3. If recovery will take more than a few minutes, we instruct the data
       centre to destroy the instance, and we WAIT FOR EXPLICIT CONFIRMATION
       that it has been destroyed. Unreachable is not dead: a primary that
       comes back mid-failover is how validators get slashed, so this
       confirmation is mandatory and the procedure stops until we have it.
    4. Only then do we redeploy on the secondary with fetch_validator_keys=true.
       The secondary is kept synced, so promotion takes minutes, not a resync.
    5. Before the new node signs we verify it is at chain tip, that
       priv_validator_state.json reflects the last signed height, and that the
       old instance is confirmed gone.
    Authorisation: ‹FILL — which roles may run this›
    ‹CONFIRM step 5's state handling, and add the Horcrux variant if live:
     with threshold signing the cluster's shared HRS state is the guard and no
     manual state file is moved.›

Link to failover runbook (optional)
    ‹FILL or leave blank — only if it contains no secrets or hostnames›

================================================================================
PAGE 6 — 5. MONITORING AND ALERTING
================================================================================

Monitoring stack
    ☑ Prometheus + Grafana (self-hosted)
    ‹CONSIDER — gnomonitoring / gnockpit are gno.land-specific tools listed as
     options. If you do not run them, leaving them unticked is honest; adopting
     one would be a cheap, visible win with this exact audience.›

What triggers an alert today?
    ☑ Missed precommits / missed blocks
    ☑ Validator absent from the valset or jailed
    ☑ Block height lag vs the network
    ☑ Node process down or restarting
    ☑ Peer count below threshold
    ☑ Disk, CPU, memory, file descriptors
    ☑ Sentry health / p2p reachability
    ‹CONFIRM each. Tick "Version drift after an upgrade" and "Certificate or
     VPN expiry" only if you actually alert on them — this is a checklist they
     will compare against your later answers.›

How does an alert reach a human at 03:00?
    ☑ PagerDuty / Opsgenie / incident.io or equivalent, with escalation
    ☑ Phone call or SMS

How many people can independently respond to an incident?
    ‹FILL — 1 / 2 / 3 to 5 / more than 5›

Time zones covered by on-call operators
    ‹FILL — if the team is all in India, say "UTC+5:30 only" and let the
     coverage answer stand on PagerDuty escalation. They ask directly and will
     notice a vague answer.›

Target ack time and RTO
    ‹FILL — e.g. "ack < 5 min, signing restored < 30 min". Your stated practice
     is a response within a minute of an alert; give numbers you will be held
     to, not aspirational ones.›

Could you execute a coordinated upgrade or emergency hard fork in 24h?
    → Yes, any day
    ‹CONFIRM — supported by the coordinated-upgrade playbook that polls to the
     agreed height, and by 24/7 PagerDuty on-call.›

Anything about on-call rota, holiday coverage, escalation
    We manage on-call in PagerDuty with escalation policies. Alerts carry tiered
    severities to reduce time-to-detect, and every alert has a written SOP in
    our internal docs to reduce time-to-recover. A security form on our website
    lets anyone trigger an immediate on-call page if a network-wide event needs
    validator action.
    ‹FILL — holiday coverage arrangement›

================================================================================
PAGE 7 — 6. SERVER ACCESS AND HARDENING
================================================================================

SSH and remote access: select everything true
    ☑ Public key authentication only
    ☑ Password authentication disabled
    ☑ Direct root login disabled
    ☑ Access only over VPN or a private network
    ☑ Access keys rotate on a defined schedule
    ‹CONFIRM — Vault-issued SSH certificates with a 1-hour TTL arguably satisfy
     "No standing SSH: session broker ... with recorded sessions" only if
     sessions are recorded. Tick that ONLY if you record sessions. Tick
     "bastion/jump host" and "MFA on the bastion or IdP" only if true.›

Under which user does the gnoland process run?
    → A dedicated non-root service user

Host firewall and network policy
    UFW, default-deny inbound, with rules applied per node type from
    version-controlled variables (roles/node/vars/ufw_rules.yml) rather than
    edited by hand. Rule changes go through the same Ansible + Semaphore path
    as any other change, so they are reviewed and logged; no operator edits
    firewall rules directly on a host.
    ‹FILL — egress restrictions: are they in place? Say plainly either way.›

How many people have shell access to the validator host?
    ‹FILL — 1 / 2 / 3 to 5 / more than 5›

How is shell access granted and revoked?
    Access is by short-lived SSH certificates issued by HashiCorp Vault:
    an operator signs their public key and receives a certificate with a 1-hour
    TTL, after which access lapses automatically. There are no long-lived
    authorised_keys entries to clean up, so a departing operator loses access
    within an hour of their Vault entitlement being removed — not whenever
    someone remembers to prune a key file.
    ‹FILL — where the source of truth for entitlements lives, and the
     offboarding checklist step that revokes it.›

Where do operational secrets (not the consensus key) live?
    ☑ HashiCorp Vault / OpenBao

Host OS and version, and patching cadence
    ‹FILL — e.g. "Ubuntu 24.04 LTS, unattended-upgrades for security patches,
     monthly reboot window". Check what the base image actually is.›

Are administrative actions on the validator logged off-host?
    ‹CONFIRM — you ship logs to Loki via Promtail, and auditd is enabled by the
     server-setup playbook. If auditd/sudo logs reach Loki, answer "Yes,
     shipped to a separate log store". If only application logs ship, answer
     "Locally only" — they can tell the difference.›

Any additional hardening worth mentioning
    Every host is hardened by our public server-setup playbook
    (github.com/encapsulate-xyz/server-setup-playbook): root login disabled,
    Fail2Ban configured, sudoers set to email alerts on unauthorised sudo
    activity, auditd enabled for audit logging, and rkhunter installed for
    rootkit detection. Deployments cannot originate from an operator's laptop —
    all Ansible runs go through a central Semaphore server.
    ‹ADD if true — SELinux/AppArmor, immutable images, file integrity
     monitoring, CIS benchmarking, any external audit or SOC 2.›

================================================================================
PAGE 8 — 7. TRACK RECORD
================================================================================

Since when have you known about gno.land, and how?
    Since around July 2025, when we began building deployment automation for
    gno.land nodes — our public gnoland-ansible repository dates from 7 July
    2025. ‹CONFIRM how you first came across it: Discord, another validator,
    an event?›

Since when validating on gno.land testnets, and which ones?
    Since July 2025, continuously across successive testnets: test7 (from
    August 2025), test13, topaz-1, sapphire-1 and now pearl-1, upgrading our
    deployment through each chain change. We are registered as a valoper on
    pearl-1 under the moniker "Encapsulate"
    (g1eyr3hfdcup4rr5xlcd63vc5t64a03u9kecx2v0).
    ‹CONFIRM this list against your own records — it is reconstructed from
     gnoland-ansible's commit history, which is public and checkable.›

Describe an incident from the last 12 months and what you changed
    ‹FILL — this is the question that most rewards a real answer. A specific
     incident with a specific change afterwards reads far better than "none".
     Across ~28 networks you will have one. Structure: what happened, how it
     was detected, time to detect and recover, what you changed so it cannot
     recur.›

Your contributions to gno.land so far, or planned
    - gno forms: a realm that publishes a form and collects responses on chain,
      with gnoweb as the only UI, so collecting structured input on gno.land no
      longer requires a Web2 backend.
      Live: https://pearl.testnets.gno.land/r/nym-encapsulate001/forms
      Source: https://github.com/encapsulate-xyz/gnoforms
    - gnolang/gno#6140: reported that an unticked checkbox in a gno-form submits
      its value regardless, making every boolean parameter unconditionally true.
      Filed with an on-chain reproduction, the served HTML, and a workaround.
      https://github.com/gnolang/gno/issues/6140
    - gnolang/gno#6141: gno-select cannot set its visible label, so users see
      parameter names where a question should be.
      https://github.com/gnolang/gno/issues/6141
    - gnoland-ansible: public deployment automation for gno.land nodes —
      deploys, upgrades, snapshot-syncs and monitors, with Vault-backed keys.
      https://github.com/encapsulate-xyz/gnoland-ansible
    Both issues were found by building on the form layer rather than reading the
    code. Planned: more field types for gno forms, per-form response numbering,
    and public endpoints and snapshots for gno.land.

Anything else the review team should know
    We have not yet registered on mainnet. Our operator address holds no GNOT
    and there is no mainnet faucet; misc/deployments/mainnet.gno.land/
    VALIDATOR.md carries an open TODO on how post-genesis operators without a
    genesis allocation should be funded. We would welcome guidance on the
    intended path.
    ‹ADD — the Bangalore, India location as a geographic-decentralisation
     point: most validator infrastructure on any network sits in Europe.›

================================================================================
PAGE 9 — 8. ATTESTATION
================================================================================

Confirm (all five required)
    ☑ No private keys, mnemonics, passwords, tokens, IPs or hostnames
       → RE-READ THE WHOLE FORM AGAINST THIS BEFORE TICKING.
    ☑ Answers describe the setup as it is today; planned items are labelled
       → Only true if you kept the PLANNED labels above.
    ☑ Will notify before materially changing key handling, hosting or failover
    ☑ Available for a follow-up call or DM
    ☑ Consent to storage in a restricted-access sheet

Name and role of person completing this form
    ‹FILL›

Date
    ‹FILL — the date you submit›
