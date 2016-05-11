# rabbitmq-cluster-ocf-vagrant

[Packer Build Scripts](https://github.com/bogdando/packer-atlas-example)
| [Atlas Vagrant Boxes (Ubuntu 14.04)](https://atlas.hashicorp.com/bogdando/boxes/rabbitmq-cluster-ocf)
| [Docker Image (Ubuntu 14.04) DEPRECATED](https://hub.docker.com/r/bogdando/rabbitmq-cluster-ocf/)
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
Required vagrant plugins: vagrant-triggers, vagrant-libvirt, fog-libvirt 0.0.3.
TODO(bogdando): add support for debian/centos/rhel images as well.

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

* For the docker provider, use the image based on Ubuntu 15.10 or 16.04. It
  has Pacemaker 1.1.12 (1.1.14), while the image with Ubuntu 14.10 is
  DEPRECATED as it contains a Pacemaker 1.1.10 that seems like has stability
  issues, when cluster members are running in VM-like containers. In the
  result, the pacemakerd daemon is stopping sporadically and the RabbitMQ
  cluster cannot assemble as well.

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

* The vagrant libvirt provider (plugin) may be
  [broken](https://github.com/fog/fog-libvirt/issues/16) for some cases. A w/a:
  ```
  vagrant plugin install --plugin-version 0.0.3 fog-libvirt
  ```

* If the terminal session looks "broken" after the ``vagrant up/down``, issue a
  ``reset`` command as well.

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

## Jepsen tests

NOTE: Works only with systemd based docker containers and the vagrant docker
provider.

[Jepsen](https://github.com/aphyr/jepsen) is good to find out how resilient,
consistent, available your distributed system is. For the Rabbitmq OCF RA case,
there are [custom tests](https://github.com/bogdando/jepsen/tree/rabbit_pcmk/rabbitmq_ocf_pcmk)
to check if the cluster recovers from network partitions well. And history
validation comes just as a free bonus :-) Although the jepsen test results may
be ignored because it maybe rather related to the
[rabbitmq itself](https://aphyr.com/posts/315-call-me-maybe-rabbitmq) than to
the OCF RA clusterer or a Pacemaker.

The idea is to bootstrap Pacemaker with Rabbitmq clusters and allow Jepsen to
continuousely do hammering of the cluster with Nemesis strikes. Then check if
the cluster has been recovered. And of cause you may want to look into the
[history validation](https://aphyr.com/posts/314-computational-techniques-in-knossos)
results as well. Hopefully, that would give you insights on the rabbitmq server
(or the pacemaker, or its rabbitmq resource) configuration settings!

Also note that both smoke and jepsen tests will perform an *integration testing*
of the complete setup, which is Corosync/Pacemaker cluster plus the RabbitMQ
cluster on top. Keep in mind that network partitions may kill the Pacemaker
cluster as well making the rabbitmq OCF RA tests results irrelevant.

To proceed with jepsen tests, firstly create an ssh key with:
```
cat /dev/random | ssh-keygen -b 1024 -t rsa -f /tmp/sshkey -q -N ""
```
Secondly, update `./conf` files as required for a test case and define the env
settings variables in the `./vagrant-settings.yaml_defaults` file. For example,
let's use `jepsen_app: rabbitmq_ocf_pcmk`, `rabbit_ver: 3.5.7`.
And also let's adjust the rabbitmq partition recovery settings as
```
--- a/conf/rabbitmq.config
+++ b/conf/rabbitmq.config
@@ -10,7 +10,7 @@
          {exit_on_close, false}]
     },
     {loopback_users, []},
-    {cluster_partition_handling, autoheal},
+    {cluster_partition_handling, pause_minority},
```

Then set `use_jepsen: "true"` in the env settings  and run ``vagrant up``.
It launches a control node n0 and five nodes named n1, n2, n3, n4, n5. Jepsen logs
and results may be found in the shared volume named `jepsen`, in the `/logs`.

NOTE: The `jepsen` volume contains a shared state, like the lein docker image and
the jepsen repo/jarfile/results, for consequent vagrant up/destroy runs. If
something went wrong, you can safely delete it. Then it will be recreated from the
scratch as well.

To collect logs at the host OS under the `/tmp/results.tar.gz`, use the command like:
```
docker run -it --rm -e "GZIP=-9" --entrypoint /bin/tar -v jepsen:/results:ro -v
/tmp:/out ubuntu cvzf /out/results.tar.gz /results/logs
```

To run lein commmands, use ``docker exec -it jepsen lein foo`` from the control node.
For example, for the `jepsen_app: jepsen`, it may be:
```
docker exec -it jepsen lein test :only jepsen.core-test/ssh-test
```
And for the `jepsen_app: rabbitmq_ocf_pcmk`, it may be either:
```
docker exec -it jepsen lein test :only jepsen.rabbitmq_ocf_pcmk-test/rabbit-test
```
or just ``lein test``, or even something like
```
bash -xx /vagrant/vagrant_script/lein_test.sh rabbitmq_ocf_pcmk
```

## Travis CI job example

There is an example dummy job ``.travis.yml_example``, which only deploys
from the given branch of the rabbitmq-server OCF RA and does a smoke test.
See also an example [job config](https://github.com/bogdando/rabbitmq-server/blob/rabbit_ocf_ra_travis/.travis.yml)
and [job script](https://github.com/bogdando/rabbitmq-server/blob/rabbit_ocf_ra_travis/scripts/travis_test_ocf_ra.sh)
for the forked rabbitmq-server repository. And here is how the
[successful build example](https://travis-ci.org/bogdando/rabbitmq-server/builds/109353708)
may look like.
