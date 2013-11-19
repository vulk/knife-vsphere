# vsphere_vm_nic_add.rb
# Author:: Rudi Heinen (rheinen@schubergphilis.com)
# License:: Apache License, Version 2.0

require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'
require 'netaddr'

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

#  option :customization_ips,
#    :long => "--cips CUST_IPS",
#    :description => "Comma-delimited list of CIDR IPs for customization"

  def generate_adapter_map (ip, mac)
    settings = RbVmomi::VIM.CustomizationIPSettings

    cidr_ip = NetAddr::CIDR.create(ip)
    settings.ip = RbVmomi::VIM::CustomizationFixedIp(:ipAddress => cidr_ip.ip)
    settings.subnetMask = cidr_ip.netmask_ext
    adapter_map = RbVmomi::VIM.CustomizationAdapterMapping
    adapter_map.adapter = settings
    adapter_map.macAddress = mac
    adapter_map
  end

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

    vm_host = vm.runtime.host.name.split('.').first
    vSwitches.each do | vswitch |
      svcheck = find_network(vswitch)
      if svcheck.host.find {|h| h == vm_host }.nil?
        ui.fatal("#{vswitch} not available on #{vm_host} for #{vm.name}")
        exit 1
      end
    end

#    cust_ips = config[:customization_ips].split(',')

    vSwitches.each do | vswitch |
#      x=0
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

      #puts vm.runtime.host.name.split('.').first
      spec = RbVmomi::VIM.VirtualMachineConfigSpec({:deviceChange => [{:operation => :add}.merge(adap_cfg)]})
      vm.ReconfigVM_Task(:spec => spec ).wait_for_completion
      puts "Finished adding " + vswitch

#      if config[:customization_ips]
#        card = vm.config.hardware.device.find { |d| d.deviceInfo.label == "Network adapter 2" }
#        pp card.macAddress
#        global_ipset = RbVmomi::VIM.CustomizationGlobalIPSettings
#        cust = RbVmomi::VIM.CustomizationSpec(:globalIPSettings => global_ipset)
#        cust.nicSettingMap = generate_adapter_map(cust_ips[x], card.macAddress)
#        pp cust
#        vm.CustomizeVM_Task(:spec => cust ).wait_for_completion
#      end
#      x+=1
    end
  end
end
