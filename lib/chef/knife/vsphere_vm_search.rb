#
# Author:: Rudi Heinen <rheinen@schubergphilis.com>
# License:: Apache License, Version 2.0
#
require 'chef/knife'
require 'chef/knife/base_vsphere_command'

# Search for virtual machines and list there props
class Chef::Knife::VsphereVmSearch < Chef::Knife::BaseVsphereCommand

  banner "knife vsphere vm search"

  get_common_options

  def search_for_vm(folder, search)
    vms = find_all_in_folder(folder, RbVmomi::VIM::VirtualMachine) 
    vms_found = vms.find_all { |f| f.name.include?(search) }
    puts "#{ui.color("Found following VM's containing name: ", :cyan)} #{search}"
    if vms_found.nil? or vms_found.empty?
      fatal_exit("No VM found with name containing #{search}")
    end
    vms_found.each do | vm |
      vmname = case vm.runtime.powerState
      when PsOn
        ui.color(vm.name, :green)
      when PsOff
        ui.color(vm.name, :red)
      when PsSuspended
        ui.color(vm.name, :yellow)
      end
      disk_size = (vm.summary.storage.committed + vm.summary.storage.uncommitted ) / (1024 * 1024 *1024)
      disk_com = vm.summary.storage.committed / (1024 * 1024 *1024)
      if vm.summary.storage.uncommitted == 0
        disk_type = "Thick"
      else
        disk_type = "Thin"
      end
      print "#{ui.color("Name:", :cyan)} #{vmname}\n"
      print "\t#{ui.color("STATUS:", :magenta)} #{vm.summary.overallStatus}\n"
      print "\t#{ui.color("STATUS:", :magenta)} #{vm.runtime.powerState}\n"
      print "\t#{ui.color("RAM:", :magenta)} #{vm.summary.config.memorySizeMB}\n"
      print "\t#{ui.color("vCPU:", :magenta)} #{vm.summary.config.numCpu}\n"
      print "\t#{ui.color("OS:", :magenta)} #{vm.config.guestFullName}\n"
      print "\t#{ui.color("HOST:", :magenta)} #{vm.runtime.host.name.split('.').first}\n"
      print "\t#{ui.color("IP:", :magenta)} #{vm.guest.ipAddress}\n"
      print "\t#{ui.color("NICS:", :magenta)} #{vm.summary.config.numEthernetCards}\n"
      print "\t#{ui.color("DISKS:", :magenta)} #{vm.summary.config.numVirtualDisks}\n"
      print "\t#{ui.color("DISK TYPE:", :magenta)} #{disk_type}\n"
      print "\t#{ui.color("DISK SIZE:", :magenta)} #{disk_size} GB\n"
      print "\t#{ui.color("DISK USED:", :magenta)} #{disk_com} GB\n"
    end
  end

  def run
    $stdout.sync = true
    vmname = @name_args[0]
    if vmname.nil?
      show_usage
      fatal_exit("You must specify a virtual machine name")
    end

    vim = get_vim_connection
    baseFolder = find_folder(get_config(:folder));
    search_for_vm(baseFolder, vmname)
  end
end
