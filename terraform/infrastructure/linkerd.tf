# Linkerd service mesh removed: the NixOS worker kernel lacks the legacy
# ip_tables module that Linkerd's proxy-init requires, and the control
# plane has been non-functional. Workloads run without sidecars anyway.
# Re-introduce only after moving to an nftables-capable Linkerd or a
# kernel with iptables support.
