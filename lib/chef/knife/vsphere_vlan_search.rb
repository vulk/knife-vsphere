# Author: Rudi Heinen <rheinen@schubergphilis.com>
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA
# OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE

require 'chef/knife'
require 'chef/knife/base_vsphere_command'

# Lists all known Switches in datacenter with sizes
class Chef::Knife::VsphereVlanSearch < Chef::Knife::BaseVsphereCommand

  banner "knife vsphere vlan Search"

  get_common_options

  def run
    $stdout.sync = true

    network = @name_args[0]
    if network.nil?
      show_usage
      fatal_exit("You must specify a network name")
    end

    vim = get_vim_connection
    lan = find_network(network)

    if lan.kind_of? RbVmomi::VIM::DistributedVirtualPortgroup
      type =  "DvSwitch"
    else
      type = "vSwitch"
    end 
    print "#{ui.color("Switch:", :cyan)}\t#{lan.config.distributedVirtualSwitch.name}\n"
    print "#{ui.color("Type:", :cyan)}\t#{type}\n"
    print "#{ui.color("Status:", :cyan)}\t#{lan.overallStatus}\n"
    print "#{ui.color("Hosts:", :cyan)}\n"
    lan.host.each do |host|
      puts "\t#{host.name}"
    end
    print "#{ui.color("Guests:", :cyan)}\n"
    lan.vm.each do |vm|
      puts "\t#{vm.name}"
    end
  end
end

