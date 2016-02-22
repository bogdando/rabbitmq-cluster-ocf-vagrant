# rabbitmq-cluster-ocf-vagrant

[Atlas Vagrant Boxes (Ubuntu 14.04)](https://atlas.hashicorp.com/bogdando/boxes/rabbitmq-cluster-ocf)
| [Docker Image (Ubuntu 14.04)](https://hub.docker.com/r/bogdando/rabbitmq-cluster-ocf/)
| [Docker Image (Ubuntu 15.10)](https://hub.docker.com/r/bogdando/rabbitmq-cluster-ocf-wily/)
| [Docker Image (Ubuntu 16.04)](https://hub.docker.com/r/bogdando/rabbitmq-cluster-ocf-xenial/)

A Vagrantfile to bootstrap and somketest a RabbitMQ cluster by the pacemaker
[OCF RA](https://github.com/rabbitmq/rabbitmq-server/blob/master/scripts/rabbitmq-server-ha.ocf).
For details, see the [docs](http://www.rabbitmq.com/pacemaker.html).

Note, there is also [rabbitmq-cluster OCF RA](https://github.com/ClusterLabs/resource-agents/blob/master/heartbeat/rabbitmq-cluster)
in the [clusterlabs/resource-agents](https://github.com/ClusterLabs/resource-agents).
With some luck, the script ``vagrant_script/conf_rabbit_primitive.sh`` may
be updated to handle the latter one as well. Hopefully, we will merge them into
the single OCF RA solution, eventually.

## Vagrantfile

Supports libvirt, virtualbox, docker (experimental) providers.
Required vagrant plugins: vagrant-triggers, vagrant-libvirt.

* Spins up two VM nodes ``[n1, n2]`` with predefined IP addressess
  ``10.10.10.2-3/24`` by default. Use the ``SLAVES_COUNT`` env var, if you need
  more nodes to form a cluster. Note, that the ``vagrant destroy`` shall accept
  the same number as well!
* Creates a corosync cluster with disabled quorum and STONITH.
* Launches a rabbitmq OCF multi-state pacemaker clone which should assemble
  the rabbit cluster automatically.
* Generates a command for a smoke test for the rabbit cluster. This may be
  run on one of the nodes (n1, n2, etc.). If the cluster assembles within couple
  of minutes, it puts `RabbitMQ cluster smoke test: PASSED`.
* Shares the host system docker daemon, images and containers. So you can
  launch nested containers as well.

Note, that constants from the ``Vagrantfile`` may be as well configred as
``vagrant-settings.yaml_defaults`` or ``vagrant-settings.yaml`` and will be
overriden by environment variables, if specified.

Also note, that for workarounds implemented for the docker provider made
the command ``vagrant ssh`` not working. Instead use the
``docker exec -it n1 bash`` or suchlike.

## Known issues

* For the docker provider, use the image based on Ubuntu 15.10 or 16.04. It has
  Pacemaker 1.1.12 (1.1.14), while the image with Ubuntu 14.10 contains Pacemaker
  1.1.10 and there is a stability issue with the pacemakerd daemon stopping
  sporadically, therefore the RabbitMQ cluster does not assemble well.

* Pacemaker >=1.1.12 seems behave better in containers, although things may be
  buggy: ``crm_node -l`` may start reporting empty nodes list, then rabbitmq OCF
  RA thinks the rabbit node is running outside of cluster and restarts. This was
  seen when using custom docker run commands, which are not ``/sbin/init``.

* For the docker provider, a networking is [not implemented](https://github.com/mitchellh/vagrant/issues/6667)
  and there is no [docker-exec privisioner](https://github.com/mitchellh/vagrant/issues/4179)
  to replace the ssh-based one. So I put ugly workarounds all around to make
  things working more or less.

* If ``vagrant destroy`` fails to teardown things, just repeat it few times more.
  Or use ``docker rm -f -v`` to force manual removal, but keep in mind that
  that will likely make your docker images directory eating more and more free
  space.

* Make sure there is no conflicting host networks exist, like
  ``packer-atlas-example0`` or ``vagrant-libvirt`` or the like. Otherwise nodes may
  become isolated from the host system.

## Troubleshooting

You may want to use the command like:
```
VAGRANT_LOG=info SLAVES_COUNT=2 vagrant up --provider docker 2>&1| tee out
```

There was added "Crafted:", "Executing:" log entries for the
provision shell scripts.

For the Rabbitmq OCF RA you may use the command like:
```
OCF_ROOT=/usr/lib/ocf /usr/lib/ocf/resource.d/rabbitmq/rabbitmq-server-ha monitor
```

It puts its logs under ``/var/log/syslog`` from the `lrmd` program tag.

## Travis CI job example

See an example [config](https://github.com/bogdando/rabbitmq-server/blob/travis_ocf_ra/.travis.yml)
for the forked rabbitmq-server repository.
A [successful build example](https://travis-ci.org/bogdando/rabbitmq-server/builds/109353708)
