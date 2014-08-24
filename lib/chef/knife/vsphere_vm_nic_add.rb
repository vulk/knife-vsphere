# vsphere_vm_nic_add.rb
# Author:: Rudi Heinen (rheinen@schubergphilis.com)
# License:: Apache License, Version 2.0

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'

# Add extra nic to a existing VM
class Chef::Knife::VsphereVmNicAdd < Chef::Knife::BaseVsphereCommand

  banner "knife vsphere vm nic add"

  get_common_options

  option :vmname,
    :short => "-n GUEST",
    :long => "--vm-name GUEST",
    :description => "The guest you want to add a nic to."

  option :vswitch,
    :short => "-s VSWITCH",
    :long => "--switch-name VSWITCH",
    :description => "Comma-delimited list vSwitches or Portgroups"

  option :type,
    :short => "-t ADAPTER TYPE",
    :long => "--nic-type ADAPTER TYPE",
    :description => "Choose either 'Vmxnet3' or 'E1000', default is Vmxnet3"

  def run
    if get_config(:vmname).nil?
      show_usage
      ui.fatal("You must specify a virtual machine name")
      exit 1
    end

    if get_config(:vswitch).nil?
      ui.fatal "You need to have a vSwitch!"
      show_usage
      exit 1
    end

    vim = get_vim_connection
    vm = get_vm(get_config(:vmname))
    vSwitches = get_config(:vswitch).split(',')

    if vm.nil?
      puts "#{vmname} doesn't exists"
      return
    end

    vSwitches.each do | vswitch |
      svcheck = find_network(vswitch)
      sv_true = false
      svcheck.host.each do | h |
        if h.name == vm.runtime.host.name
          sv_true = true
        end 
      end
      if sv_true == false
        ui.fatal("#{vswitch} not available on #{vm_host} for #{vm.name}")
        exit 1
      end
    end

    vSwitches.each do | vswitch |
      portgrp = find_network(vswitch)
      nic = {:addressType => 'generated'}
      k = vm.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).count+1
      default_cfg = {:key => k, :deviceInfo => {:label =>"Network Adapter #{k}", :summary => vswitch || 'VM Network' }}.merge(nic)

      if portgrp.kind_of? RbVmomi::VIM::DistributedVirtualPortgroup
        nic_cfg = {:backing =>  RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
          :port =>  RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
            :switchUuid => portgrp.config.distributedVirtualSwitch.uuid,
            :portgroupKey => portgrp.key
          )
        )}
      else
        nic_cfg = { :backing => RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(
          :deviceName => vswitch || 'VM Network',
          :port => {
            :switchUuid => vswitch || 'VM Network'
          }
        )}
      end

      adap_type = get_config(:type) unless get_config(:type).nil?
      if get_config(:type).nil? || get_config(:type) == "Vmxnet3"
        adap_cfg = {:device => RbVmomi::VIM.VirtualVmxnet3({}.merge(default_cfg).merge(nic_cfg))}
      elsif get_config(:type) == "E1000"
        adap_cfg = {:device => RbVmomi::VIM.VirtualE1000({}.merge(default_cfg).merge(nic_cfg))}
      else
        show_usage
        exit 1
      end

      spec = RbVmomi::VIM.VirtualMachineConfigSpec({:deviceChange => [{:operation => :add}.merge(adap_cfg)]})
      vm.ReconfigVM_Task(:spec => spec ).wait_for_completion
      puts "Finished adding " + vswitch

    end
  end
end
