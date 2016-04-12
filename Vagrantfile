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
OCF_RA_PATH = ENV['OCF_RA_PATH'] || cfg['ocf_ra_path']
UPLOAD_METHOD = ENV['UPLOAD_METHOD'] || cfg ['upload_method']
USE_JEPSEN = ENV['USE_JEPSEN'] || cfg ['use_jepsen']
JEPSEN_APP = ENV['JEPSEN_APP'] || cfg ['jepsen_app']
SMOKETEST_WAIT = ENV['SMOKETEST_WAIT'] || cfg ['smoketest_wait']
RABBIT_VER = ENV['RABBIT_VER'] || cfg ['rabbit_ver']
if USE_JEPSEN == "true"
  SLAVES_COUNT = 4
else
  SLAVES_COUNT = (ENV['SLAVES_COUNT'] || cfg['slaves_count']).to_i
end

# FIXME(bogdando) more natively to distinguish a provider specific logic
provider = (ARGV[2] || ENV['VAGRANT_DEFAULT_PROVIDER'] || :docker).to_sym

def shell_script(filename, env=[], args=[])
  shell_script_crafted = "/bin/bash -c \"#{env.join ' '} #{filename} #{args.join ' '} 2>/dev/null\""
  @logger.info("Crafted shell-script: #{shell_script_crafted})")
  shell_script_crafted
end

# W/a unimplemented docker-exec, see https://github.com/mitchellh/vagrant/issues/4179
# Use docker exec instead of the SSH provisioners
def docker_exec (name, script)
  @logger.info("Executing docker-exec at #{name}: #{script}")
  system "docker exec -it #{name} #{script}"
end

# Render a rabbitmq config and a pacemaker primitive configuration
rabbit_primitive_setup = shell_script("/vagrant/vagrant_script/conf_rabbit_primitive.sh")
rabbit_ha_pol_setup = shell_script("cp /vagrant/conf/set_rabbitmq_policy.sh /tmp/rmq-ha-pol")
rabbit_install = shell_script("/vagrant/vagrant_script/rabbit_install.sh", [], [RABBIT_VER])
rabbit_conf_setup = shell_script("cp /vagrant/conf/rabbitmq.config /etc/rabbitmq/")
rabbit_env_setup = shell_script("cp /vagrant/conf/rabbitmq-env.conf /etc/rabbitmq/")
cib_cleanup = shell_script("/vagrant/vagrant_script/conf_cib_cleanup.sh")

# FIXME(bogdando) remove rendering rabbitmq OCF script setup after v3.5.7 released
# and got to the UCA packages
rabbit_ocf_setup = shell_script("/vagrant/vagrant_script/conf_rabbit_ocf.sh",
  ["UPLOAD_METHOD=#{UPLOAD_METHOD}", "OCF_RA_PATH=#{OCF_RA_PATH}"])

# Setup lein, jepsen and hosts/ssh access for it
# Render rabbit node names for the smoke test
jepsen_setup = shell_script("/vagrant/vagrant_script/conf_jepsen.sh")
lein_test = shell_script("/vagrant/vagrant_script/lein_test.sh", [], [JEPSEN_APP])
ssh_setup = shell_script("/vagrant/vagrant_script/conf_ssh.sh")
rabbit_nodes = ["rabbit@n1"]
entries = "'#{IP24NET}.2 n1'"
cmd = ["ssh-keyscan -t rsa n1,#{IP24NET}.2 >> ~/.ssh/known_hosts"]
SLAVES_COUNT.times do |i|
  index = i + 2
  ip_ind = i + 3
  entries += " '#{IP24NET}.#{ip_ind} n#{index}'"
  rabbit_nodes << "rabbit@n#{index}"
  cmd << "ssh-keyscan -t rsa n#{index},#{IP24NET}.#{ip_ind} >> ~/.ssh/known_hosts"
end
rabbit_test = shell_script("/vagrant/vagrant_script/test_rabbitcluster.sh",
  ["WAIT=#{SMOKETEST_WAIT}"], rabbit_nodes)
hosts_setup = shell_script("/vagrant/vagrant_script/conf_hosts.sh", [], [entries])
ssh_allow = shell_script(cmd.join("\n"))

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  if provider == :docker
    # W/a unimplemented docker networking, see
    # https://github.com/mitchellh/vagrant/issues/6667.
    # Create or delete the rabbits net (depends on the vagrant action)
    config.trigger.before :up do
      system <<-SCRIPT
      if ! docker network inspect rabbits >/dev/null 2>&1 ; then
        docker network create -d bridge \
          -o "com.docker.network.bridge.enable_icc"="true" \
          -o "com.docker.network.bridge.enable_ip_masquerade"="true" \
          -o "com.docker.network.driver.mtu"="1500" \
          --gateway=#{IP24NET}.1 \
          --ip-range=#{IP24NET}.0/24 \
          --subnet=#{IP24NET}.0/24 \
          rabbits >/dev/null 2>&1
      fi
      SCRIPT
    end
    config.trigger.after :destroy do
      system <<-SCRIPT
      docker network rm rabbits >/dev/null 2>&1
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
  else
    config.vm.box = IMAGE_NAME
  end

  # A Jepsen only case, set up a contol node
  if provider == :docker and USE_JEPSEN == "true"
    # Use the n1 to run the smoketest from the control node
    rabbit_test = shell_script("/vagrant/vagrant_script/test_rabbitcluster.sh",
      ["WAIT=#{SMOKETEST_WAIT}","AT_NODE=n1"], rabbit_nodes)
    config.vm.define "n0", primary: true do |config|
      config.vm.host_name = "n0"
      config.vm.provider :docker do |d, override|
        d.name = "n0"
        d.create_args = [ "--stop-signal=SIGKILL", "-i", "-t", "--privileged", "--ip=#{IP24NET}.254", "--net=rabbits",
          docker_volumes].flatten
      end
      config.trigger.after :up, :option => { :vm => 'n0' } do
        docker_exec("n0","#{jepsen_setup} >/dev/null 2>&1")
        docker_exec("n0","#{hosts_setup} >/dev/null 2>&1")
        docker_exec("n0","#{ssh_setup} >/dev/null 2>&1")
        docker_exec("n0","#{ssh_allow} >/dev/null 2>&1")
        # Wait and run a smoke test against a cluster, shall not fail
        docker_exec("n0","#{rabbit_test}") or raise "Smoke test: FAILED to assemble a cluster"
        # this runs all of the jepsen tests for the given app, and it *may* fail
        docker_exec("n0","#{lein_test}")
        # Verify if the cluster was recovered, shall not fail
        docker_exec("n0","#{rabbit_test}") or raise "Smoke test: FAILED to recover the cluster after a Nemesis strike"
      end
    end
  end

  config.vm.define "n1", primary: true do |config|
    config.vm.host_name = "n1"
    corosync_setup = shell_script("/vagrant/vagrant_script/conf_corosync.sh", [], ["#{IP24NET}.2"])
    if provider == :docker
      config.vm.provider :docker do |d, override|
        d.name = "n1"
        d.create_args = [ "--stop-signal=SIGKILL", "-i", "-t", "--privileged", "--ip=#{IP24NET}.2", "--net=rabbits",
          docker_volumes].flatten
      end
      config.trigger.after :up, :option => { :vm => 'n1' } do
        docker_exec("n1","#{rabbit_install}") or raise "Failed to install requested rabbitmq package"
        docker_exec("n1","#{corosync_setup} >/dev/null 2>&1")
        docker_exec("n1","#{rabbit_ocf_setup}")
        docker_exec("n1","#{rabbit_ha_pol_setup} >/dev/null 2>&1")
        docker_exec("n1","#{rabbit_conf_setup} >/dev/null 2>&1")
        docker_exec("n1","#{rabbit_env_setup} >/dev/null 2>&1")
        docker_exec("n1","#{rabbit_primitive_setup} >/dev/null 2>&1")
        docker_exec("n1","#{cib_cleanup} >/dev/null 2>&1")
        if USE_JEPSEN == "true"
          docker_exec("n1","#{ssh_setup} >/dev/null 2>&1")
          docker_exec("n1","#{ssh_allow} >/dev/null 2>&1")
        else
          # Wait and run a smoke test against a cluster, shall not fail
          docker_exec("n1","#{rabbit_test}") or raise "Smoke test: FAILED to assemble a cluster"
        end
      end
    else
      config.vm.network :private_network, ip: "#{IP24NET}.2", :mode => 'nat'
      config.vm.provision "shell", run: "always", inline: rabbit_install, privileged: true
      config.vm.provision "shell", run: "always", inline: corosync_setup, privileged: true
      config.vm.provision "shell", run: "always", inline: rabbit_ocf_setup, privileged: true
      config.vm.provision "shell", run: "always", inline: rabbit_primitive_setup, privileged: true
      config.vm.provision "shell", run: "always", inline: cib_cleanup, privileged: true
    end
  end

  SLAVES_COUNT.times do |i|
    index = i + 2
    ip_ind = i + 3
    raise if ip_ind > 254
    config.vm.define "n#{index}" do |config|
      config.vm.host_name = "n#{index}"
      # wait 2 seconds for the first corosync node
      corosync_setup = shell_script("/vagrant/vagrant_script/conf_corosync.sh", [], ["#{IP24NET}.#{ip_ind}", 2])
      if provider == :docker
        config.vm.provider :docker do |d, override|
          d.name = "n#{index}"
          d.create_args = ["--stop-signal=SIGKILL", "-i", "-t", "--privileged", "--ip=#{IP24NET}.#{ip_ind}", "--net=rabbits",
            docker_volumes].flatten
        end
        config.trigger.after :up, :option => { :vm => "n#{index}" } do
          if USE_JEPSEN == "true"
            docker_exec("n#{index}","#{ssh_setup} >/dev/null 2>&1")
            docker_exec("n#{index}","#{ssh_allow} >/dev/null 2>&1")
          end
          docker_exec("n#{index}","#{rabbit_install}") or raise "Failed to install requested rabbitmq package"
          docker_exec("n#{index}","#{corosync_setup} >/dev/null 2>&1")
          docker_exec("n#{index}","#{rabbit_ocf_setup}")
          docker_exec("n#{index}","#{rabbit_ha_pol_setup} >/dev/null 2>&1")
          docker_exec("n#{index}","#{rabbit_conf_setup} >/dev/null 2>&1")
          docker_exec("n#{index}","#{rabbit_env_setup} >/dev/null 2>&1")
          docker_exec("n#{index}","#{cib_cleanup} >/dev/null 2>&1")
        end
      else
        config.vm.network :private_network, ip: "#{IP24NET}.#{ip_ind}", :mode => 'nat'
        config.vm.provision "shell", run: "always", inline: rabbit_install, privileged: true
        config.vm.provision "shell", run: "always", inline: corosync_setup, privileged: true
        config.vm.provision "shell", run: "always", inline: rabbit_ocf_setup, privileged: true
        config.vm.provision "shell", run: "always", inline: cib_cleanup, privileged: true
      end
    end
  end
end
