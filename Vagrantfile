# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'log4r'
require 'yaml'

# configs, custom updates _defaults
@logger = Log4r::Logger.new("vagrant::docker::driver")
defaults_cfg = YAML.load_file('vagrant-settings.yaml_defaults')
if File.exist?('vagrant-settings.yaml')
  custom_cfg = YAML.load_file('vagrant-settings.yaml')
  cfg = defaults_cfg.merge(custom_cfg)
else
  cfg = defaults_cfg
end

IP24NET = ENV['IP24NET'] || cfg['ip24net']
IMAGE_NAME = ENV['IMAGE_NAME'] || cfg['image_name']
DOCKER_IMAGE = ENV['DOCKER_IMAGE'] || cfg['docker_image']
DOCKER_CMD = ENV['DOCKER_CMD'] || cfg['docker_cmd']
DOCKER_MOUNTS = ENV['DOCKER_MOUNTS'] || cfg['docker_mounts']
OCF_RA_PROVIDER = ENV['OCF_RA_PROVIDER'] || cfg['ocf_ra_provider']
OCF_RA_PATH = ENV['OCF_RA_PATH'] || cfg['ocf_ra_path']
UPLOAD_METHOD = ENV['UPLOAD_METHOD'] || cfg ['upload_method']
USE_JEPSEN = ENV['USE_JEPSEN'] || cfg ['use_jepsen']
JEPSEN_APP = ENV['JEPSEN_APP'] || cfg ['jepsen_app']
JEPSEN_TESTCASE = ENV['JEPSEN_TESTCASE'] || cfg ['jepsen_testcase']
QUIET = ENV['QUIET'] || cfg ['quiet']
SMOKETEST_WAIT = ENV['SMOKETEST_WAIT'] || cfg ['smoketest_wait']
RABBIT_VER = ENV['RABBIT_VER'] || cfg ['rabbit_ver']
if USE_JEPSEN == "true"
  SLAVES_COUNT = 4
else
  SLAVES_COUNT = (ENV['SLAVES_COUNT'] || cfg['slaves_count']).to_i
end
if QUIET == "true"
  REDIRECT=">/dev/null 2>&1"
else
  REDIRECT="2>&1"
end

def shell_script(filename, env=[], args=[], redirect=REDIRECT)
  shell_script_crafted = "/bin/bash -c \"#{env.join ' '} #{filename} #{args.join ' '} #{redirect}\""
  @logger.info("Crafted shell-script: #{shell_script_crafted})")
  shell_script_crafted
end

# W/a unimplemented docker-exec, see https://github.com/mitchellh/vagrant/issues/4179
# Use docker exec instead of the SSH provisioners
def docker_exec (name, script)
  @logger.info("Executing docker-exec at #{name}: #{script}")
  system "docker exec -it #{name} #{script}"
end

# Render a rabbitmq config and a pacemaker primitive configuration with a seed node n1
corosync_setup = shell_script("/vagrant/vagrant_script/conf_corosync.sh")
rabbit_primitive_setup = shell_script("/vagrant/vagrant_script/conf_rabbit_primitive.sh",
  ["SEED=n1"])
rabbit_ha_pol_setup = shell_script("cp /vagrant/conf/set_rabbitmq_policy.sh /tmp/rmq-ha-pol")
rabbit_install = shell_script("/vagrant/vagrant_script/rabbit_install.sh", [], [RABBIT_VER])
rabbit_conf_setup = shell_script("cp /vagrant/conf/rabbitmq.config /etc/rabbitmq/")
rabbit_env_setup = shell_script("cp /vagrant/conf/rabbitmq-env.conf /etc/rabbitmq/")

# FIXME(bogdando) remove rendering rabbitmq OCF script setup after v3.5.7 released
# and got to the UCA packages
rabbit_ocf_setup = shell_script("/vagrant/vagrant_script/conf_rabbit_ocf.sh",
  ["UPLOAD_METHOD=#{UPLOAD_METHOD}", "OCF_RA_PATH=#{OCF_RA_PATH}",
   "OCF_RA_PROVIDER=#{OCF_RA_PROVIDER}"])

# Setup docker dropins, lein, jepsen and hosts/ssh access for it
jepsen_setup = shell_script("/vagrant/vagrant_script/conf_jepsen.sh")
docker_dropins = shell_script("/vagrant/vagrant_script/conf_docker_dropins.sh")
pcmk_dropins = shell_script("/vagrant/vagrant_script/conf_pcmk_dropins.sh")
lein_test = shell_script("/vagrant/vagrant_script/lein_test.sh", ["PURGE=true"],
  [JEPSEN_APP, JEPSEN_TESTCASE], "1>&2")
ssh_setup = shell_script("/vagrant/vagrant_script/conf_ssh.sh",[], [SLAVES_COUNT+1], "1>&2")
root_login = shell_script("/vagrant/vagrant_script/conf_root_login.sh")
entries = "'#{IP24NET}.2 n1'"
SLAVES_COUNT.times do |i|
  index = i + 2
  ip_ind = i + 3
  entries += " '#{IP24NET}.#{ip_ind} n#{index}'"
end
rabbit_test_remote = shell_script("/vagrant/vagrant_script/test_rabbitcluster.sh",
  ["AT_NODE=n1", "WAIT=#{SMOKETEST_WAIT}"], [SLAVES_COUNT+1], "1>&2")
rabbit_test = shell_script("/vagrant/vagrant_script/test_rabbitcluster.sh",
  ["WAIT=#{SMOKETEST_WAIT}"], [SLAVES_COUNT+1], "1>&2")
hosts_setup = shell_script("/vagrant/vagrant_script/conf_hosts.sh", [], [entries])

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # W/a unimplemented docker networking, see
  # https://github.com/mitchellh/vagrant/issues/6667.
  # Create or delete the vagrant net (depends on the vagrant action)
  config.trigger.before :up do
    system <<-SCRIPT
    if ! docker network inspect "vagrant-#{OCF_RA_PROVIDER}" >/dev/null 2>&1 ; then
      docker network create -d bridge \
        -o "com.docker.network.bridge.enable_icc"="true" \
        -o "com.docker.network.bridge.enable_ip_masquerade"="true" \
        -o "com.docker.network.driver.mtu"="1500" \
        --gateway=#{IP24NET}.1 \
        --ip-range=#{IP24NET}.0/24 \
        --subnet=#{IP24NET}.0/24 \
        "vagrant-#{OCF_RA_PROVIDER}" >/dev/null 2>&1
    fi
    SCRIPT
  end
  config.trigger.after :destroy do
    system <<-SCRIPT
    docker network rm "vagrant-#{OCF_RA_PROVIDER}" >/dev/null 2>&1
    SCRIPT
  end

  config.vm.provider :docker do |d, override|
    d.image = DOCKER_IMAGE
    d.remains_running = false
    d.has_ssh = false
    d.cmd = DOCKER_CMD.split(' ')
  end

  # Prepare docker volumes for nested containers
  docker_volumes = [ "-v", "/sys/fs/cgroup:/sys/fs/cgroup",
    "-v", "/var/run/docker.sock:/var/run/docker.sock" ]
  if DOCKER_MOUNTS != 'none'
    if DOCKER_MOUNTS.kind_of?(Array)
      mounts = DOCKER_MOUNTS
    else
      mounts = DOCKER_MOUNTS.split(" ")
    end
    mounts.each do |m|
      next if m == "-v"
      docker_volumes << [ "-v", m ]
    end
  end

  # A Jepsen only case, set up a contol node
  if USE_JEPSEN == "true"
    config.vm.define "n0", primary: true do |config|
      config.vm.host_name = "n0"
      config.vm.provider :docker do |d, override|
        d.name = "n0"
        d.create_args = [ "--stop-signal=SIGKILL", "-i", "-t", "--privileged", "--ip=#{IP24NET}.254",
          "--memory=512", "--cpu-shares=333",
          "--net=vagrant-#{OCF_RA_PROVIDER}", docker_volumes].flatten
      end
      config.trigger.after :up, :option => { :vm => 'n0' } do
        docker_exec("n0","#{jepsen_setup}")
        docker_exec("n0","#{hosts_setup}")
        docker_exec("n0","#{ssh_setup}")
        # Wait and run a smoke test against a cluster, shall not fail
        docker_exec("n0","#{rabbit_test_remote}") or raise "Smoke test: FAILED to assemble a cluster"
        # this runs all of the jepsen tests for the given app, and it *may* fail
        docker_exec("n0","#{docker_dropins}")
        docker_exec("n0","#{lein_test}")
        # Verify if the cluster was recovered, shall not fail
        docker_exec("n0","#{rabbit_test_remote}")
      end
    end
  end

  COMMON_TASKS = [root_login, ssh_setup, corosync_setup, pcmk_dropins, rabbit_install, rabbit_ocf_setup,
                  rabbit_primitive_setup, rabbit_ha_pol_setup, rabbit_conf_setup, rabbit_env_setup]

  config.vm.define "n1", primary: true do |config|
    config.vm.host_name = "n1"
    config.vm.provider :docker do |d, override|
      d.name = "n1"
      d.create_args = [ "--stop-signal=SIGKILL", "-i", "-t", "--privileged",
        "--memory=512", "--cpu-shares=333",
        "--ip=#{IP24NET}.2", "--net=vagrant-#{OCF_RA_PROVIDER}", docker_volumes].flatten
    end
    config.trigger.after :up, :option => { :vm => 'n1' } do
      COMMON_TASKS.each { |s| docker_exec("n1","#{s}") }
      # Wait and run a smoke test against a cluster, shall not fail
      docker_exec("n1","#{rabbit_test}") unless USE_JEPSEN == "true"
    end
  end

  SLAVES_COUNT.times do |i|
    index = i + 2
    ip_ind = i + 3
    raise if ip_ind > 254
    config.vm.define "n#{index}" do |config|
      config.vm.host_name = "n#{index}"
      config.vm.provider :docker do |d, override|
        d.name = "n#{index}"
        d.create_args = ["--stop-signal=SIGKILL", "--shm-size=500m", "-i", "-t", "--privileged",
          "--ip=#{IP24NET}.#{ip_ind}", "--net=vagrant-#{OCF_RA_PROVIDER}", docker_volumes].flatten
      end
      config.trigger.after :up, :option => { :vm => "n#{index}" } do
        COMMON_TASKS.each { |s| docker_exec("n#{index}","#{s}") }
      end
    end
  end
end
