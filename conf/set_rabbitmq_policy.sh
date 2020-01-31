# This script is called by rabbitmq-server-ha.ocf during RabbitMQ
# cluster start up. It is a convenient place to set your cluster
# policy here, for example:
# ${OCF_RESKEY_ctl} set_policy ha-all "." '{"ha-mode":"all", "ha-sync-mode":"automatic", "ha-sync-batch-size":10000}'

# Enable ha-policy with the replica factor of 5 for jepsen queues
ocf_log info "${LH} Setting HA policy for all queues"
${OCF_RESKEY_ctl} set_policy ha-all "jepsen." '{"ha-mode":"exactly", "ha-params":2, "ha-sync-mode":"automatic"}'
