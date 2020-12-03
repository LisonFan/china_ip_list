#!/bin/bash

ROOT_PATH="/home/china_ip_list/"
TEMP_FILE_PATH="/home/china_ip_list/temp/"
SURGE_PATH="/home/china_ip_list/Surge/"
SSR_PATH="/home/china_ip_list/SSR/"
ACL_PATH="/home/china_ip_list/ACL/"
PCAP_DNSPROXY_PATH="/home/china_ip_list/Pcap_DNSProxy/"
SCRIPT_PATH="/home/china_ip_list/Script"

CurrentDate=$(date +%Y-%m-%d)

downloadOriginIPList() {
	echo "exec downloadOriginIPList."

	rm -rf $TEMP_FILE_PATH
	mkdir $TEMP_FILE_PATH
	cd $TEMP_FILE_PATH

	wget -e "https_proxy=http://127.0.0.1:8118" -O apnic https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest >$TEMP_FILE_PATH'apnic.log' 2>&1

	wget -e "https_proxy=http://127.0.0.1:8118" -O ipip https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt >$TEMP_FILE_PATH'ipip.log' 2>&1

	while ((1)); do
		apnicIsDownDone=$(cat $TEMP_FILE_PATH'apnic.log' | grep -E "saved|已保存" | wc -l)
		ipipIsDownDone=$(cat $TEMP_FILE_PATH'ipip.log' | grep -E "saved|已保存" | wc -l)
		if [ $apnicIsDownDone == 1 ] && [ $ipipIsDownDone == 1 ]; then
			echo -e "ip files download done."
			break
		fi
		sleep 1
	done

	sleep 1
	handelChinaIPv4List
}

handelChinaIPv4List() {
	echo "exec handelChinaIPv4List."

	echo -e "" >>ipip
	mv ipip china_ipv4_list
	cp china_ipv4_list $ROOT_PATH

	sleep 1
	handelChinaIPv6List
}

handelChinaIPv6List() {
	echo "exec handelChinaIPv6List."

	cat apnic | grep ipv6 | grep CN | awk -F\| '{printf("%s/%d\n", $4, $5)}' >china_ipv6_list

	cp china_ipv6_list $ROOT_PATH

	sleep 1
	handelChinaIPv4IPv6List
}

handelChinaIPv4IPv6List() {
	echo "exec handelChinaIPv4IPv6List."

	cat china_ipv4_list >china_ipv4_ipv6_list
	cat china_ipv6_list >>china_ipv4_ipv6_list

	cp china_ipv4_ipv6_list $ROOT_PATH

	sleep 1
	handelPcapDNSProxyRules
}

handelPcapDNSProxyRules() {
	echo "exec handelPcapDNSProxyRules."

	echo -e "[Local Routing]\n## China mainland routing blocks\n## Sources: https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest" >Pcap_DNSProxy_Routing.txt
	echo -n "## Last update: " >>Pcap_DNSProxy_Routing.txt
	echo $CurrentDate >>Pcap_DNSProxy_Routing.txt
	echo -e "" >>Pcap_DNSProxy_Routing.txt

	# IPv4
	echo "## IPv4" >>Pcap_DNSProxy_Routing.txt
	cat china_ipv4_list >>Pcap_DNSProxy_Routing.txt
	echo -e "" >>Pcap_DNSProxy_Routing.txt

	# IPv6
	echo "## IPv6" >>Pcap_DNSProxy_Routing.txt
	cat china_ipv6_list >>Pcap_DNSProxy_Routing.txt

	mv Pcap_DNSProxy_Routing.txt Routing.txt

	mv Routing.txt $PCAP_DNSPROXY_PATH

	sleep 1
	handelSurgeRules
}

handelSurgeRules() {
	echo "exec handelSurgeRules."

	echo -e "// China IP" >surge_rules.txt
	echo -n "// Last update: " >>surge_rules.txt
	echo $CurrentDate >>surge_rules.txt

	sed 's/^/IP-CIDR,/g' china_ipv4_list >surge_ipv4_rules_header.txt
	sed 's/$/,DIRECT/g' surge_ipv4_rules_header.txt >surge_ipv4_rules.txt

	sed 's/^/IP-CIDR6,/g' china_ipv6_list >surge_ipv6_rules_header.txt
	sed 's/$/,DIRECT/g' surge_ipv6_rules_header.txt >surge_ipv6_rules.txt

	echo -n "// IPv4" >>surge_rules.txt
	echo -e "" >>surge_rules.txt
	cat surge_ipv4_rules.txt >>surge_rules.txt
	echo -e "" >>surge_rules.txt
	echo -n "// IPv6" >>surge_rules.txt
	echo -e "" >>surge_rules.txt
	cat surge_ipv6_rules.txt >>surge_rules.txt

	mv surge_rules.txt Rules.conf

	sed 's/^/IP-CIDR,/g' china_ipv4_list >surge_ipv4_rules_set.list
	sed 's/^/IP-CIDR6,/g' china_ipv6_list >surge_ipv6_rules_set.list

	mv Rules.conf surge_ipv4_rules_set.list surge_ipv6_rules_set.list $SURGE_PATH

	sleep 1
	handelACLRules
}

handelACLRules() {
	echo "exec handelACLRules."

	echo -n "# Last update: " >acl_rules.txt
	echo $CurrentDate >>acl_rules.txt
	echo -e "[proxy_all]\n" >>acl_rules.txt
	echo "[bypass_list]" >>acl_rules.txt
	echo "# 局域网 IP" >>acl_rules.txt
	echo "^(.*\.)?local$" >>acl_rules.txt
	echo "^(.*\.)?localhost$" >>acl_rules.txt
	echo "10.0.0.0/8" >>acl_rules.txt
	echo "127.0.0.0/8" >>acl_rules.txt
	echo "172.16.0.0/12" >>acl_rules.txt
	echo "192.168.0.0/16" >>acl_rules.txt
	echo "" >>acl_rules.txt
	echo "# China IP" >>acl_rules.txt
	cat china_ipv4_list >>acl_rules.txt

	mv acl_rules.txt china_ip_list.acl

	mv china_ip_list.acl $ACL_PATH

	sleep 1
	handelSSRRules
}

handelSSRRules() {
	echo "exec handelSSRRules."

	cd $SCRIPT_PATH
	python ssr_chn_ip.py

	sleep 1
	cleanTempFile
}

cleanTempFile() {
	echo "exec cleanTempFile."

	cd $ROOT_PATH
	rm -rf $TEMP_FILE_PATH

	sleep 1
	commit
}

commit() {
	git add --all
	git commit -m "update"
	git push origin master
}

downloadOriginIPList
