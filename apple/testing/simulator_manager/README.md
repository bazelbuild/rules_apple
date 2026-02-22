# `simulator_manager`

The `simulator_manager` replaces the `simulator_creator.py` used in
**rules_apple**'s `ios_xctestrun_runner.template.sh`.

It manages simulator "leases". Tests can lease and then release a simulator of a
given configuration (device type and os version), and can also request that it's
an "exclusive" lease. The manager automatically releases a simulator if the
requested process exits without releasing first.

Exclusive leases mean that test has exclusive access to the simulator, which is
needed for App Host and UI tests.

Base simulators are created for a given configuration, leases are on clones of
the base simulators. After a simulator has been released for 10 minutes the
clone is deleted. This allows us to free up disk space on remote executors, but
also allow reuse in a short period of time.
