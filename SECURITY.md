# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Report them privately through GitHub's
[private vulnerability reporting](../../security/advisories/new) for this repository instead.

Include steps to reproduce, the affected version or commit, and the impact you expect. You should get a reply within a week.

## Scope

Enough runs entirely on the device, with no backend. Relevant reports include:

- ways a web page loaded in the WebView could reach the app's JavaScript bridge, files or settings
- bypasses of the PIN lock or lockout
- leaks of cookies, usage data or settings (backups, logs, exported components)

Bugs in the third-party sites themselves are out of scope. Report those to the platform.
