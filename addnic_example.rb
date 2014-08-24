require 'rbvmomi'

class KnifeVspherePlugin
	def data=(cplugin_data)
		@network = cplugin_data
	end

	def reconfig_vm(target_vm)
		@network = @network.split(",").each {|t| t.strip!}
		def_gw = @network[-1]
		if def_gw =~ /GW=(.*)/
			gw_interface = $1
			@network.delete_at(-1)
		else
			gw_interface = "front"
		end
        	s = target_vm.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).size
        	nics = {:addressType => 'generated'}
		dnic = target_vm.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).find{|nic| nic.props}
		@network.each do |network|
    			spec = RbVmomi::VIM.VirtualMachineConfigSpec({:deviceChange => [{
        		  :operation => :add,
        		  :device => RbVmomi::VIM.VirtualVmxnet3({
        		    :key => s,
        		    :deviceInfo => {
        		      :label => "Network Adapter #{s}",
           		      :summary => network || 'VM Network'
            		    },
            		    :backing => RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(
              	   	      :deviceName => network || 'VM Network'
           		    ) 
          		  }.merge(nics))
        		}]})
    			target_vm.ReconfigVM_Task(:spec => spec ).wait_for_completion
    			puts "Finished configuring " + network
		end
		@card = target_vm.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).map { |x| [x.deviceInfo.label, x.macAddress, x.deviceInfo.summary] }
		hostname = target_vm.config.name
		nic_ks =  "#{hostname}-ks"
                nic_admin =  "#{hostname}-admin"
                nic_front =  "#{hostname}-front"
                nic_back =  "#{hostname}-back"
                nic_nfs =  "#{hostname}-nfs"
                @hostnames = [nic_ks, nic_admin, nic_front, nic_back, nic_nfs]

		net = Hash.new
		ipaddress = Hash.new
		netmasks = Hash.new
		broadcasts = Hash.new
		networks = Hash.new
		namings = Hash.new
		def_gateway = Hash.new
		dns = Hash.new
		@card.each do |nic_card|
			if nic_card[2] =~ /BLADELOGIC/
				ip = search_ip("#{nic_ks}")
				( bc, network, nm ) = getNetmask("#{ip}")
				if bc == nil
					print "Network does not exists in /etc/networks for IP #{ip}\n"
					netmasks = {"netmasks" => {"eth4" => "nil"}}
	                                broadcasts = {"broadcasts" => {"eth4" => "nil"}}
					networks = {"networks" => {"eth4" => "nil"}}
					namings = {"naming" => {"build" => "#{nic_card[1]}"}}
				else
					netmasks = {"netmasks" => {"eth4" => "#{nm}"}}
                                        broadcasts = {"broadcast" => {"eth4" => "#{bc}"}}
                                        networks = {"networks" => {"eth4" => "#{network}"}}
					namings = {"naming" => {"build" => "#{nic_card[1]}"}}
				end
				net = {"net" => {"eth4" => "#{nic_card[1]}"}}
				ipaddress = {"ip" => {"eth4" => "#{ip}"}}
                        end
                        if nic_card[2] =~ /ADM/
				ip = search_ip("#{nic_admin}")
				( bc, network, nm ) = getNetmask("#{ip}")
                                if bc == nil
		                        print "Network does not exists in /etc/networks for IP #{ip}\n"
					netmasks["netmasks"]["eth0"]="nil"
	                                broadcasts["broadcasts"]["eth0"]="nil"
					networks["networks"]["eth0"]="nil"
					namings["naming"]["admin"]="#{nic_card[1]}"
                                else
					netmasks["netmasks"]["eth0"]="#{nm}"
                                        broadcasts["broadcasts"]["eth0"]="#{bc}"
                                        networks["networks"]["eth0"]="#{network}"
					namings["naming"]["admin"]="#{nic_card[1]}"
                                end
				net["net"]["eth0"]="#{nic_card[1]}"
				ipaddress["ip"]["eth0"]="#{ip}"
                        end
                        if nic_card[2] =~ /FRONT/
				ip = search_ip("#{nic_front}")
				( bc, network, nm ) = getNetmask("#{ip}")
				if bc == nil
                                        print "Network does not exists in /etc/networks for IP #{ip}\n"
                                        netmasks["netmasks"]["eth1"]="nil"
                                        broadcasts["broadcasts"]["eth1"]="nil"
                                        networks["networks"]["eth1"]="nil"
					namings["naming"]["front"]="#{nic_card[1]}"
                                else
                                        netmasks["netmasks"]["eth1"]="#{nm}"
                                        broadcasts["broadcasts"]["eth1"]="#{bc}"
                                        networks["networks"]["eth1"]="#{network}"
					namings["naming"]["front"]="#{nic_card[1]}"
                                end
				net["net"]["eth1"]="#{nic_card[1]}"
                                ipaddress["ip"]["eth1"]="#{ip}"
                        end
	                if nic_card[2] =~ /BACK/
				ip = search_ip("#{nic_back}")
				( bc, network, nm ) = getNetmask("#{ip}")
				if bc == nil
                                        print "Network does not exists in /etc/networks for IP #{ip}\n"
                                        netmasks["netmasks"]["eth2"]="nil"
                                        broadcasts["broadcasts"]["eth2"]="nil"
                                        networks["networks"]["eth2"]="nil"
					namings["naming"]["back"]="#{nic_card[1]}"
                                else
                                        netmasks["netmasks"]["eth2"]="#{nm}"
                                        broadcasts["broadcasts"]["eth2"]="#{bc}"
                                        networks["networks"]["eth2"]="#{network}"
					namings["naming"]["back"]="#{nic_card[1]}"
                                end
				net["net"]["eth2"]="#{nic_card[1]}"
                                ipaddress["ip"]["eth2"]="#{ip}"
                        end
                        if nic_card[2] =~ /NAS/
				ip = search_ip("#{nic_nfs}")
				( bc, network, nm ) = getNetmask("#{ip}")
				if bc == nil
                                        print "Network does not exists in /etc/networks for IP #{ip}\n"
                                        netmasks["netmasks"]["eth3"]="nil"
                                        broadcasts["broadcasts"]["eth3"]="nil"
                                        networks["networks"]["eth0"]="nil"
					namings["naming"]["san"]="#{nic_card[1]}"
                                else
                                        netmasks["netmasks"]["eth3"]="#{nm}"
                                        broadcasts["broadcasts"]["eth3"]="#{bc}"
                                        networks["networks"]["eth3"]="#{network}"
					namings["naming"]["san"]="#{nic_card[1]}"
                                end
				net["net"]["eth3"]="#{nic_card[1]}"
                                ipaddress["ip"]["eth3"]="#{ip}"
                        end
		end
		 host = {
                  "id" => "#{hostname}",
                }
		host = host.merge(net)
		host = host.merge(ipaddress)
		host = host.merge(netmasks)
		host = host.merge(broadcasts)
		host = host.merge(networks)
		host = host.merge(namings)

		databag_item = Chef::DataBagItem.new
		databag_item.data_bag("udev")
		databag_item.raw_data = host
		databag_item.save

		my_bag = Chef::DataBagItem.load("udev", "#{hostname}")
                if_gw = my_bag["naming"]["#{gw_interface}"]
                mac_to_if = getIFgw(if_gw, "#{hostname}")
		ipaddr = my_bag["ip"]["#{mac_to_if}"]
		( bc, network, nm ) = getNetmask("#{ipaddr}")
		def_gw = getGateway(network)
		
		# add dns
		env = hostname[0,4]
		env = env.downcase
		case env
		        when "abnt"
		                dns1 = search_ip("abnadc1-front")
		                dns2 = search_ip("abnadc3-front")
				dns = {"dns" => {"dns1" => "#{dns1}"}}
				dns["dns"]["dns2"]="#{dns2}"
		        when "abna"
		        when "abnp"
		        else
		end


		host = {
		  "id" => "#{hostname}",
                  "def_gw" => "#{def_gw}",
                }

		host = host.merge(net)
                host = host.merge(ipaddress)
                host = host.merge(netmasks)
                host = host.merge(broadcasts)
                host = host.merge(networks)
                host = host.merge(namings)
		host = host.merge(dns)

		databag_item = Chef::DataBagItem.new
                databag_item.data_bag("udev")
                databag_item.raw_data = host
                databag_item.save

	end
	def search_ip(host)
		host_ip = `grep #{host} /etc/hosts`
                ip = host_ip.split()
                ip = ip[0]
	end
	def getNetmask(ipA)
	        f = File.open("/etc/netmasks", "r")
        	f.each do |line|
        	        line.chomp
        	        line.gsub(/\s+/, "")
        	        next if line =~ /^#/
        	        next if line =~ /^$/
        	        (ip, nm) = line.split()
        	        command = `/bin/ipcalc -b -n #{ip} #{nm}`
        	        if command =~ /BROADCAST=(.*)/
        	                bc = $1
        	        end
        	        if command =~ /NETWORK=(.*)/
        	                net = $1
        	        end
        	        # Now convert all three to numbers and see
        	        # if the IP is in the range
        	        ipn_i = IPtoNumber(ipA);
        	        ipn_n = IPtoNumber(net);
        	        ipn_b = IPtoNumber(bc);
	                if ipn_i > ipn_n and ipn_i < ipn_b
				return bc, net, nm
	                end
	        end
		return nil
	end


	def IPtoNumber(ipn)
	        @octets = ipn.split( /\./)
	        ret = 0
	        @octets.each do |octet|
	                octet = octet.to_i
	                ret <<= 8
	                ret |= octet
	        end
	        return ret
	end
	def getIFgw(mac,hostname)
		my_bag = Chef::DataBagItem.load("udev", "#{hostname}")
		iface = my_bag["net"]
		iface.each do |iface,macaddr|
			if "#{macaddr}" == "#{mac}"
				mac = "#{iface}"
			end
		end
		return mac
	end
	def getGateway(net)
	        f = File.open("/etc/gateways", "r")
	        f.each do |line|
	                line.chomp
	                line.gsub(/\s+/, "")
	                next if line =~ /^#/
	                next if line =~ /^$/
	                if line =~ /^(\d+.\d+.\d+.\d+)/
	                        ip = $1
	                        if "#{ip}" == "#{net}"
	                                a = line.split(/\t?\s/)
	                                gw = a[1]
	                                return gw
	                        end
	                end
	        end
	end
end
