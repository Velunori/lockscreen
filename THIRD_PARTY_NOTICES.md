# Omarchy

`Service.qml` is an unmodified copy of Omarchy 4.0.6-1
`shell/plugins/lock/Service.qml`. Its PAM flows, fingerprint handling,
WlSessionLock surfaces, multi-monitor behavior, failsafes and stable `lock` IPC
remain owned by Omarchy. Checks refuse service drift after an upstream update.
`LockView.qml` retains the original view's property/signal interface and input
synchronization behavior, with a new Serene presentation.

Copyright (c) David Heinemeier Hansson. MIT license included in `LICENSE`.
Upstream: https://github.com/basecamp/omarchy.
