# Hippo Remote OSC Setup

Complete this once on every Hippotizer server that Hippo Remote will control.

1. Open **Multicontroller** in ZooKeeper.
2. Add an **OSC Input**.
3. Select the network adapter used by the grandMA3/Hippo data network.
4. Set the OSC input port to **7000**.
5. Create these system-operation Action Mappings and target the local host:

| Text Mapping | Hippotizer Action |
| --- | --- |
| `/hippo/shutdown/machine` | Shutdown Machine |
| `/hippo/restart/machine` | Restart Machine |
| `/hippo/shutdown/host` | Shutdown Software / Shutdown Host |

Use integer input values. Hippo Remote sends `1` to trigger the action and then `0` to reset it.

Allow the configured inbound UDP port for Hippotizer on the intended show-network adapter.

No OSC output needs to be created in grandMA3. The plugin sends UDP directly to each selected Network Node IP address.
