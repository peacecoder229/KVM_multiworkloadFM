vhost.o: vhost.c /root/rohan_exp/spdk/include/spdk/stdinc.h \
 /root/rohan_exp/spdk/include/spdk/env.h \
 /root/rohan_exp/spdk/include/spdk/queue.h \
 /root/rohan_exp/spdk/include/spdk/queue_extras.h \
 /root/rohan_exp/spdk/include/spdk/pci_ids.h \
 /root/rohan_exp/spdk/include/spdk/likely.h \
 /root/rohan_exp/spdk/include/spdk/string.h \
 /root/rohan_exp/spdk/include/spdk/util.h \
 /root/rohan_exp/spdk/include/spdk/memory.h \
 /root/rohan_exp/spdk/include/spdk/barrier.h \
 /root/rohan_exp/spdk/include/spdk/vhost.h \
 /root/rohan_exp/spdk/include/spdk/cpuset.h \
 /root/rohan_exp/spdk/include/spdk/json.h \
 /root/rohan_exp/spdk/include/spdk/thread.h vhost_internal.h \
 /root/rohan_exp/spdk/include/linux/virtio_config.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_vhost.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_memory.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_bitops.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_debug.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_log.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_common.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_config.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_build_config.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_os.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_compat.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_branch_prediction.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_fbarray.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_rwlock.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_rwlock.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_atomic.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_atomic.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_atomic_64.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_pause.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_pause.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_spinlock.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_spinlock.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_lcore.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_per_lcore.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_eal.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_bus.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_log.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_dev.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_uuid.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_pci_dev_feature_defs.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_launch.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_thread.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_rtm.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_cpuflags.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_cpuflags.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_common.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_pause.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_cycles.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_cycles.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_mempool.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_spinlock.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_branch_prediction.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_core.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_memzone.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_elem.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_elem_pvt.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_generic_pvt.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_hts.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_hts_elem_pvt.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_rts.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_rts_elem_pvt.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_peek.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_peek_elem_pvt.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_ring_peek_zc.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_memcpy.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_vect.h \
 /root/rohan_exp/spdk/dpdk/build/include/generic/rte_vect.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_mempool_trace_fp.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_trace_point.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_cycles.h \
 /root/rohan_exp/spdk/dpdk/build/include/rte_string_fns.h \
 /root/rohan_exp/spdk/include/spdk_internal/vhost_user.h \
 /root/rohan_exp/spdk/include/spdk/bdev.h \
 /root/rohan_exp/spdk/include/spdk/scsi_spec.h \
 /root/rohan_exp/spdk/include/spdk/assert.h \
 /root/rohan_exp/spdk/include/spdk/nvme_spec.h \
 /root/rohan_exp/spdk/include/spdk/histogram_data.h \
 /root/rohan_exp/spdk/include/spdk/dif.h \
 /root/rohan_exp/spdk/include/spdk/log.h \
 /root/rohan_exp/spdk/include/spdk/rpc.h \
 /root/rohan_exp/spdk/include/spdk/jsonrpc.h \
 /root/rohan_exp/spdk/include/spdk/config.h

/root/rohan_exp/spdk/include/spdk/stdinc.h:

/root/rohan_exp/spdk/include/spdk/env.h:

/root/rohan_exp/spdk/include/spdk/queue.h:

/root/rohan_exp/spdk/include/spdk/queue_extras.h:

/root/rohan_exp/spdk/include/spdk/pci_ids.h:

/root/rohan_exp/spdk/include/spdk/likely.h:

/root/rohan_exp/spdk/include/spdk/string.h:

/root/rohan_exp/spdk/include/spdk/util.h:

/root/rohan_exp/spdk/include/spdk/memory.h:

/root/rohan_exp/spdk/include/spdk/barrier.h:

/root/rohan_exp/spdk/include/spdk/vhost.h:

/root/rohan_exp/spdk/include/spdk/cpuset.h:

/root/rohan_exp/spdk/include/spdk/json.h:

/root/rohan_exp/spdk/include/spdk/thread.h:

vhost_internal.h:

/root/rohan_exp/spdk/include/linux/virtio_config.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_vhost.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_memory.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_bitops.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_debug.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_log.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_common.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_config.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_build_config.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_os.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_compat.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_branch_prediction.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_fbarray.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_rwlock.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_rwlock.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_atomic.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_atomic.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_atomic_64.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_pause.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_pause.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_spinlock.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_spinlock.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_lcore.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_per_lcore.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_eal.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_bus.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_log.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_dev.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_uuid.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_pci_dev_feature_defs.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_launch.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_thread.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_rtm.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_cpuflags.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_cpuflags.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_common.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_pause.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_cycles.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_cycles.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_mempool.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_spinlock.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_branch_prediction.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_core.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_memzone.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_elem.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_elem_pvt.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_generic_pvt.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_hts.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_hts_elem_pvt.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_rts.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_rts_elem_pvt.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_peek.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_peek_elem_pvt.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_ring_peek_zc.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_memcpy.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_vect.h:

/root/rohan_exp/spdk/dpdk/build/include/generic/rte_vect.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_mempool_trace_fp.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_trace_point.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_cycles.h:

/root/rohan_exp/spdk/dpdk/build/include/rte_string_fns.h:

/root/rohan_exp/spdk/include/spdk_internal/vhost_user.h:

/root/rohan_exp/spdk/include/spdk/bdev.h:

/root/rohan_exp/spdk/include/spdk/scsi_spec.h:

/root/rohan_exp/spdk/include/spdk/assert.h:

/root/rohan_exp/spdk/include/spdk/nvme_spec.h:

/root/rohan_exp/spdk/include/spdk/histogram_data.h:

/root/rohan_exp/spdk/include/spdk/dif.h:

/root/rohan_exp/spdk/include/spdk/log.h:

/root/rohan_exp/spdk/include/spdk/rpc.h:

/root/rohan_exp/spdk/include/spdk/jsonrpc.h:

/root/rohan_exp/spdk/include/spdk/config.h:
