# Hippotizer V4 OSC setup

Server Command automatically discovers the IP address of every connected MA Network Node whose type is `MediaServer`. No machine address is entered manually.

The default UDP port is `7000`. The default action paths are:

- Shutdown Machine: `/hippo/shutdown/machine`
- Restart Machine: `/hippo/restart/machine`
- Stop Engine Host: `/hippo/shutdown/host`

Create matching OSC Action Mappings in Hippotizer V4. Each mapping should perform its named operation when receiving integer `1`. Server Command sends `1` followed by `0` to each selected server.

The port and paths can be changed from **Preferences** without changing individual device IP addresses.
