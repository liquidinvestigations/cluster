#!/bin/bash -ex

# from https://min.io/resources/docs/MinIO-Throughput-Benchmarks-on-HDD-24-Node.pdf
# maximum number of open files/file descriptors
sysctl fs.file-max=4194303
# use as little swap space as possible
sysctl vm.swappiness=1
# prioritize application RAM against disk/swap cache
sysctl vm.vfs_cache_pressure=10
# minimum free memory
sysctl vm.min_free_kbytes=1000000
# maximum receive socket buffer (bytes)
sysctl net.core.rmem_max=268435456
# maximum send buffer socket buffer (bytes)
sysctl net.core.wmem_max=268435456
# default receive buffer socket size (bytes)
sysctl net.core.rmem_default=67108864
# default send buffer socket size (bytes)
sysctl net.core.wmem_default=67108864
# maximum number of packets in one poll cycle
sysctl net.core.netdev_budget=1200
# maximum ancillary buffer size per socket
sysctl net.core.optmem_max=134217728
# maximum number of incoming connections
sysctl net.core.somaxconn=65535
# maximum number of packets queued
sysctl net.core.netdev_max_backlog=250000
# maximum read buffer space
sysctl net.ipv4.tcp_rmem="67108864 134217728 268435456"
# maximum write buffer space
sysctl net.ipv4.tcp_wmem="67108864 134217728 268435456"
# enable low latency mode
sysctl net.ipv4.tcp_low_latency=1

# socket buffer portion used for TCP window
sysctl net.ipv4.tcp_adv_win_scale=1
# queue length of completely established sockets waiting for accept
sysctl net.ipv4.tcp_max_syn_backlog=30000
# maximum number of sockets in TIME_WAIT state
sysctl net.ipv4.tcp_max_tw_buckets=2000000
# reuse sockets in TIME_WAIT state when safe
sysctl net.ipv4.tcp_tw_reuse=1
# time to wait (seconds) for FIN packet
sysctl net.ipv4.tcp_fin_timeout=5
# disable icmp send redirects
# sysctl net.ipv4.conf.all.send_redirects=0
# disable icmp accept redirect
# sysctl net.ipv4.conf.all.accept_redirects=0
# drop packets with LSR or SSR
# sysctl net.ipv4.conf.all.accept_source_route=0
# MTU discovery, only enable when ICMP blackhole detected
# sysctl net.ipv4.tcp_mtu_probing=1

# elasticsearch
sysctl vm.max_map_count=262144
