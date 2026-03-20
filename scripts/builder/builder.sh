#!/bin/bash

func_networking() {
	
	### Set IPv4 - DHCP or Static
	echo ""
	echo "NETWORKING"
	echo ""
	nmcli
	read -p "Do you want to configure IPv4 for an interface (y/N): " change

	while [[ "$change" == [Yy] ]]; do

		echo "Enter NIC name: "
		read NIC

		echo "Enter ipv4 method (static ; auto): "
		read method

		if [[ "$method" != "auto" ]]; then

			#Set Address and mask
			echo "Enter ipv4 address/mask: "
			read address
			if [[ -n $address ]]; then
				nmcli connection modify $NIC ipv4.address $address
			fi

			#Set Default Gateway
			echo "Enter ipv4 default-gateway: "
			read gateway
			if [[ -n $gateway ]]; then
				nmcli connection modify $NIC ipv4.gateway $gateway
			fi

			#Set DNS servers
			echo "Enter DNS servers: "
			read DNS
			if [[ -n $DNS ]]; then
				nmcli connection modify $NIC ipv4.dns $DNS
			fi

			nmcli connection modify $NIC ipv4.method $method
			nmcli networking off
			sleep 2
			nmcli networking on
		fi

		echo ""
		read -p "Do you want to modify another interface (y/N): " change
		echo ""
	done
	
	func_menu
}

func_packages() {
	### Update packages + enable basic extra repos (crb, plus, epel-release)
	echo ""
	echo "DNF PACKAGES"
	echo ""
	read -p "Do you want to update packages (y/N): " change

	if [[ $change == [Yy] ]]; then
		dnf update -y
		dnf config-manager --set-enabled plus
		dnf config-manager --set-enabled crb
		dnf install epel-* -y
	fi
	
	func_menu
}

func_hostname() {
	### Change hostname

	read -p "Do you want to change hostname (y/N): " change

	if [[ $change == [Yy] ]]; then
		read -p "Enter new hostname: " newname
		hostnamectl hostname $newname
	fi
	
	func_menu
}

func_selinux() {
	### Setup selinux

	echo ""
	echo "SELINUX"
	sestatus
	echo ""
	read -p "Do you want to modify selinux configuration (y/N): " change
	if [[ $change == [Yy] ]]; then
		read -p "Choose mode (enforcing ; permissive ; disabled): " mode
		sed -i "/SELINUX=/c\SELINUX=${mode}" /etc/selinux/config
	fi

	if [[ "$mode" == "permissive" || "$mode" == "disabled" ]]; then
		setenforce 0
	else
		setenforce 1
	fi

	sestatus
	
	func_menu
}

func_firewall() {
	### Setup firewall-cmd

	echo ""
	echo "FIREWALL"
	ip a
	echo ""
	read -p "Do you want to make a change to a firewall zone (y/N): " change
	while [[ $change == [Yy] ]]; do

		read -p "Destination zone: " zone

		read -p "Do you want to move an interface to zone: $zone: (y/N)" changeint
		while [[ $changeint == [Yy] ]]; do
			read -p "Interface to be modified: " interface
			firewall-cmd --zone=$zone --change-interface=$interface --permanent
			read -p "Do you want to move another interface to zone: $zone: (y/N)" changeint
		done

		read -p "Do you want to add services to zone: $zone: (y/N)" changeser
		while [[ $changeser == [Yy] ]]; do
			read -p "Service to add: " service
			firewall-cmd --zone=$zone --add-service=$service --permanent
			read -p "Do you want to add some more services to zone: $zone: (y/N)" changeser
		done

		read -p "Do you want to add some ports to zone: $zone: (y/N)" changeport
		while [[ $changeport == [Yy] ]]; do
			read -p "Port to add: " port
			firewall-cmd --zone=$zone --add-port=$port --permanent
			read -p "Do you want to add some more ports to zone: $zone: (y/N)" changeser
		done

		read -p "Do you want to change another zone (y/N): " change
	done

	firewall-cmd --reload
	
	func_menu
}

func_dhcp() {
	### Setup DHCP server
	echo ""
	echo "DHCP SERVER"
	echo ""
	read -p "Do you want to download dhcp-server (y/N): " change
	if [[ $change == [Yy] ]]; then
		dnf install dhcp-server -y
	fi

	echo ""
	read -p "Do you want to configure the DHCP server (y/N): " change
	if [[ $change == [Yy] ]]; then

		read -p "Do you want to add a subnet (y/N): " subnet

		while [[ $subnet == [Yy] ]]; do
			read -p "Enter subnet: " subnet
			read -p "Enter mask: " netmask
			read -p "Enter Range Start: " rangeStart
			read -p "Enter Range End: " rangeEnd
			read -p "Enter name server: " nameServer
			read -p "Enter domain name: " domain
			read -p "Enter default gateway: " gateway
			read -p "Enter broadcast address: " broadcast
			read -p "Enter default lease time: " defaultLease
			read -p "Enter max lease time: " maxLease

			cat >> /etc/dhcp/dhcpd.conf <<EOF

subnet $subnet netmask $netmask {
  range $rangeStart $rangeEnd;
  option domain-name-servers $nameServer;
  option domain-name "$domain";
  option routers $gateway;
  option broadcast-address $broadcast;
  default-lease-time $defaultLease;
  max-lease-time $maxLease;
}

EOF

		read -p "Do you want to add another subnet (y/N): " subnet
		done

		read -p "Do you want to add a fixed reservation (y/N): " fixed
		while [[ $fixed == [Yy] ]]; do

			read -p "Enter host name: " host
			read -p "Enter NIC's MAC address: " mac
			read -p "Enter ip reservation: " IPv4

			cat >> /etc/dhcp/dhcpd.conf<<EOF

host $host {
  hardware ethernet $mac;
  fixed-address $IPv4;
}

EOF
		read -p "Do you want to add another fixed reservation (y/N): " fixed
		done
		systemctl enable --now dhcpd
	fi
	
	func_menu
}

func_dns() {
	### Setup DNS server
	echo ""
	echo "DNS SERVER"
	echo ""
	read -p "Do you want to download bind(DNS) (y/N): " change
	if [[ $change == [Yy] ]]; then
		dnf install bind -y
	fi

	echo ""
	read -p "Do you want to configure the DNS server (y/N): " change
	if [[ $change == [Yy] ]]; then

		### Basic Listen / Query / Transfer / Forwarders options
		
		# Listen / Query
		read -p "Do you want to modify basic listen/query options (y/N): " change
		if [[ $change == [Yy] ]]; then
			read -p "Listen on port 53 (127.0.0.1;x.x.x.x;y.y.y.y): " listen
			read -p "Allow query from (localhost;x.x.x.0/XX;y.y.y.0/YY): " query
				
			sed -i "/listen-on port 53/c\	listen-on port 53 { $listen; };" /etc/named.conf
			sed -i "/allow-query/c\	allow-query	{ $query; };" /etc/named.conf
		fi
		
		# Transfer
		read -p "Do you want to add a transfer option (y/N): " change2
		if [[ $change2 == [Yy] ]]; then
			read -p "Allow transfer to (x.x.x.x;y.y.y.y): " transfer
			sed -i "/options {/r /dev/stdin" /etc/named.conf <<EOF
    allow-transfer { $transfer; };
EOF
		fi
		
		# Forwarders
		read -p "Do you want to add a forwarders option (y/N): " change3
		if [[ $change3 == [Yy] ]]; then
			read -p "Forwarders (x.x.x.x;y.y.y.y): " forwarders
			sed -i "/options {/r /dev/stdin" /etc/named.conf <<EOF
    forwarders { $forwarders; };
EOF
		fi
		
		### Master zone
		read -p "Do you want to add a master zone (y/N): " change
		if [[ $change == [Yy] ]]; then
			
			# /etc/named.conf
			read -p "Enter zone: " zone
			read -p "Enter file: " file
			cat >> /etc/named.conf <<EOF

zone "$zone" IN {
  type master;
  file "$file";
};
EOF

			# /var/named/zonefile
			read -p "Enter admin email (ex: invalid.mail.com.): " mail
			read -p "Enter NS (@	IN	NS	Aa.Bb.Cc.): " NS
			read -p "Enter A  (@	IN	A	IP)" A
			read -p "Enter A  (Aa	IN	A	IP)" A2

			cat > /var/named/$file<<EOF
\$TTL 3H
@       IN SOA  @ $mail (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
$NS
$A
$A2
EOF

			cat /var/named/$file
			read -p "Add another line (y/N): " line
			if [[ $line == [Yy] ]]; then
				nano /var/named/$file
			fi

			chown named:named /var/named/$file
			chmod 640 /var/named/$file
			systemctl enable named
			systemctl restart named
		fi
	
		### Master reversed lookup zone
		read -p "Do you want to add a master reversed lookup zone (y/N): " change
		if [[ $change == [Yy] ]]; then

			# /etc/named.conf
			read -p "Enter zone (reversed network IP - CCC.BBB.AAA): " zone
			read -p "Enter file: " file

			cat >> /etc/named.conf <<EOF

zone "$zone.in-addr.arpa" IN {
  type master;
  file "$file";
};
EOF

			# /var/named/reversedzonefile
			read -p "Enter server FQDN (ex: Aa.Bb.Cc.): " fqdn
			read -p "Enter admin email (ex: invalid.mail.com.): " mail
			read -p "Enter NS 	(@	IN	NS	Aa.Bb.Cc.): " NS
			read -p "Enter PTR  (@	IN	PTR	Bb.Cc.)" PTR
			read -p "Enter A 	(Aa	IN	A	IP)" A

			cat > /var/named/$file<<EOF
\$TTL 3H
@       IN SOA	$fqdn $mail (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
$NS
$PTR
$A
EOF

			cat /var/named/$file
			read -p "Add another line (y/N): " line
			if [[ $line == [Yy] ]]; then
				nano /var/named/$file
			fi

			chown named:named /var/named/$file
			chmod 640 /var/named/$file
			systemctl enable named
			systemctl restart named
		fi
	
		### Slave zone
		read -p "Do you want to add a slave zone (y/N): " change
		if [[ $change == [Yy] ]]; then
			
			# /etc/named.conf
			read -p "Enter zone: " zone
			read -p "Enter file (slaves/file.abc.db): " file
			read -p "Enter masters (xxx.xxx.xxx.xxx;yyy.yyy.yyy.yyy): " masters
			echo ""
			echo "This server will have to be added to the allow-transfer option of master servers"
			echo ""
			cat >> /etc/named.conf <<EOF

zone "$zone" IN {
  type slave;
  file "$file";
  masters { $masters; };
};
EOF
		fi
		
		### Forwarder zone
		read -p "Do you want to add a forwarder zone (y/N): " change
		if [[ $change == [Yy] ]]; then
			
			# /etc/named.conf
			read -p "Enter zone: " zone
			read -p "Enter forwarders (xxx.xxx.xxx.xxx;yyy.yyy.yyy.yyy): " forwarders
			read -p "Enter forwarding option (first ; only): " option
			cat >> /etc/named.conf <<EOF

zone "$zone" {
  type forward;
  forward $option;
  forwarders { $forwarders; };
};
EOF
		fi
	fi
	
	func_menu
}

func_http() {
	### HTTP / APACHE
	echo ""
	echo "HTTP / APACHE"
	echo ""
	read -p "Do you want to download httpd (y/N): " change
	if [[ $change == [Yy] ]]; then
		dnf install httpd mod_ssl -y
	fi

	## Hotes Virtuels



	## SSL/TLS
	read -p "Do you want to generate a self signed SSL key/certificate pair (y/N): " change
	if [[ $change == [Yy] ]]; then
		mkdir /root/certs
		cd /root/certs
		pwd
		# CA - private key and certificate
		openssl genrsa -des3 -out my-ca.key 2048
		openssl req -new -x509 -days 3650 -key my-ca.key -out my-ca.crt
		# private key
		openssl genrsa -des3 -out local.key 2048
		# certificate request
		openssl req -new -key local.key -out local.csr
		# Request CA to sign certificate
		openssl x509 -req -CA my-ca.crt -CAkey my-ca.key -in local.csr -out local.crt -days 365 -CAcreateserial
		
		# Remove password from key
		openssl rsa -in local.key -out local.key.new
		mv local.key.new local.key

		read -p "Do you want to use these with httpd (y/N): " change
		if [[ $change == [Yy] ]]; then
			mkdir /etc/httpd/conf/ssl-key
			mkdir /etc/httpd/conf/ssl-crt
			cp local.key /etc/httpd/conf/ssl-key/
			cp local.crt /etc/httpd/conf/ssl-crt/
			cp my-ca.crt /etc/httpd/conf/ssl-crt/
			
			# Virtual host for https
			read -p "Enter IP address for the https website: " IP
			read -p "Server Name: " fqdn
			read -p "Enter the https website document root: " documentRoot

			cat >> /etc/httpd/conf.d/ssl.conf <<EOF
<VirtualHost $IP:443>
DocumentRoot "$documentRoot"
ServerName $fqdn:443
SSLEngine on
SSLCertificateFile /etc/httpd/conf/ssl-crt/local.crt
SSLCertificateKeyFile /etc/httpd/conf/ssl-key/local.key
SSLCACertificateFile /etc/httpd/conf/ssl-crt/my-ca.crt
</VirtualHost>

EOF
			systemctl restart httpd
			netstat -tna | grep 443
		fi
	fi

	## Authentification


	
	func_menu
}

func_ldap() {
	set -e

	read -p "Enter server FQDN: " fqdn
	IFS='.' read -ra parts <<< "$fqdn"

	read -p "Enter LDAP admin CN (e.g. admin): " admin

	dnf install -y dnf-plugins-core
	dnf config-manager --set-enabled plus || true
	dnf install -y openldap-servers openldap-clients openssl

	systemctl enable --now slapd

	# Enable LDAPS
	cat > /etc/sysconfig/slapd <<EOF
SLAPD_URLS="ldap:/// ldapi:/// ldaps:///"
EOF

	# Firewall
	read -p "Enter firewall zone for ldaps usage: " zone
	firewall-cmd --zone=$zone --add-service=ldap --permanent
	firewall-cmd --zone=$zone --add-service=ldaps --permanent
	firewall-cmd --zone=$zone --reload

	# Admin password
	slappasswd > /root/ldap_admin.hash
	ADMIN_HASH=$(cat /root/ldap_admin.hash)

	# Load schemas
	for s in cosine nis inetorgperson; do
	  ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/${s}.ldif
	done

	# Configure database
	cat > /root/db.ldif <<EOF
dn: olcDatabase={2}mdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=${parts[1]},dc=${parts[2]}
-
replace: olcRootDN
olcRootDN: cn=${admin},dc=${parts[1]},dc=${parts[2]}
-
replace: olcRootPW
olcRootPW: ${ADMIN_HASH}
-
add: olcDbIndex
olcDbIndex: uid eq
olcDbIndex: uidNumber eq
olcDbIndex: gidNumber eq
EOF

	ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/db.ldif

	# Base DIT
	cat > /root/base.ldif <<EOF
dn: dc=${parts[1]},dc=${parts[2]}
objectClass: top
objectClass: dcObject
objectClass: organization
o: ${parts[1]}
dc: ${parts[1]}

dn: cn=${admin},dc=${parts[1]},dc=${parts[2]}
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: ${admin}
userPassword: ${ADMIN_HASH}

dn: ou=People,dc=${parts[1]},dc=${parts[2]}
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=${parts[1]},dc=${parts[2]}
objectClass: organizationalUnit
ou: Group
EOF

	ldapadd -x -D cn=${admin},dc=${parts[1]},dc=${parts[2]} -W -f /root/base.ldif

	# Test user
	slappasswd > /root/testuser.hash
	USER_HASH=$(cat /root/testuser.hash)

	cat > /root/user.ldif <<EOF
dn: uid=testuser,ou=People,dc=${parts[1]},dc=${parts[2]}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: testuser
sn: user
uidNumber: 2000
gidNumber: 2000
homeDirectory: /home/testuser
loginShell: /bin/bash
userPassword: ${USER_HASH}
shadowMax: 99999
shadowWarning: 7

dn: cn=testuser,ou=Group,dc=${parts[1]},dc=${parts[2]}
objectClass: posixGroup
cn: testuser
gidNumber: 2000
memberUid: testuser
EOF

	ldapadd -x -D cn=${admin},dc=${parts[1]},dc=${parts[2]} -W -f /root/user.ldif

	# TLS (self-signed, CN = FQDN)
	openssl req -x509 -nodes -days 365 \
	  -newkey rsa:2048 \
	  -keyout /etc/pki/tls/ldap.key \
	  -out /etc/pki/tls/ldap.crt \
	  -subj "/CN=${fqdn}"

	chown ldap:ldap /etc/pki/tls/ldap.*

	cat > /root/tls.ldif <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/pki/tls/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/pki/tls/ldap.key
-
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/pki/tls/ldap.crt
EOF

	ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/tls.ldif

	systemctl restart slapd

	echo "LDAP server ready (LDAPS on 636)"
	
	cp /etc/pki/tls/ldap.crt /etc/pki/ca-trust/source/anchors/ldap.crt
	update-ca-trust extract
	
	ss -tulpen | grep slapd

}

func_ldapClient(){
	
	set -e

	read -p "Enter LDAP server FQDN: " fqdn
	IFS='.' read -ra parts <<< "$fqdn"

	read -p "Enter LDAP bind user CN: " binduser
	read -s -p "Enter LDAP bind password: " bindpw
	echo

	dnf install -y openldap-clients sssd sssd-ldap oddjob-mkhomedir authselect

	authselect select sssd with-mkhomedir --force
	systemctl enable --now oddjobd

	mkdir -p /etc/openldap/certs
	scp root@${fqdn}:/etc/pki/tls/ldap.crt /etc/openldap/certs/ca.pem

	cat > /etc/openldap/ldap.conf <<EOF
URI ldaps://${fqdn}/
BASE dc=${parts[1]},dc=${parts[2]}
TLS_CACERT /etc/openldap/certs/ca.pem
EOF

	cat > /etc/sssd/sssd.conf <<EOF
[sssd]
services = nss, pam
domains = default

[domain/default]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldaps://${fqdn}/
ldap_search_base = dc=${parts[1]},dc=${parts[2]}
ldap_tls_reqcert = demand
cache_credentials = true
ldap_default_bind_dn = cn=${binduser},dc=${parts[1]},dc=${parts[2]}
ldap_default_authtok = ${bindpw}
EOF

	chmod 600 /etc/sssd/sssd.conf
	systemctl enable --now sssd
	systemctl restart sssd

	getent passwd testuser && echo "LDAP authentication works"	
}

func_phpldap() {
	
	cat > /etc/httpd/conf.d/phpldapadmin.conf << EOF
<VirtualHost 192.168.10.1:443>
    ServerName ldap.myLab.tld

    DocumentRoot /usr/share/phpldapadmin/htdocs

    <Directory /usr/share/phpldapadmin/htdocs>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/phpldapadmin-error.log
    CustomLog /var/log/httpd/phpldapadmin-access.log combined

    SSLEngine on
    SSLCertificateFile /etc/pki/tls/ldap.crt
    SSLCertificateKeyFile /etc/pki/tls/ldap.key

</VirtualHost>
EOF
	
	cat > /etc/phpldapadmin/config.php << 'EOF'
<?php

$config->custom->session['blowfish'] = 'd75e197cb034b2f471e0ddf2f8c5a861';  // unique secret for cookies

/* Server configuration */
$servers = new Datastore();
$servers->newServer('ldap_pla');

$servers->setValue('server','name','Local LDAP Server');
$servers->setValue('server','host','SrvA.myLab.tld');
$servers->setValue('server','port',389);
$servers->setValue('server','tls',true);


$servers->setValue('server','tls_cacert','/etc/pki/tls/cert.pem');

// Base DN for your LDAP tree
$servers->setValue('server','base',array('dc=myLab,dc=tld'));

// Bind user for searching (Manager)
$servers->setValue('login','bind_id','cn=Manager,dc=myLab,dc=tld');
// Leave blank in config.local.php to avoid storing password in plaintext
$servers->setValue('login','bind_pass','');

?>
EOF
}

func_sshKey() {
	read -p "Enter a comment to describe this key: " comment
	read -p "Enter which user will use it: " myuser
	read -p "Enter which server to send it to: " myserver
	
	ssh-keygen -t ed25519 -C "$comment"
	ssh-copy-id $myuser@$myserver
	
	func_menu
}

func_nfs() {
	
	read -p "Do you want to install nfs-utils (y/N): " change
	if [[ $change == [yY] ]]; then
		dnf install nfs-utils -y
		systemctl enable nfs-server rpcbind
	fi
	
	read -p "Do you want to export a directory (y/N): " change
	while [[ $change == [yY] ]]; do
		
		read -p "Do you want to add an entry to /etc/exports (y/N): " change3
		if [[ $change3 == [yY] ]]; then
			read -p "Do you want to create a new directory (y/N): " change2
			if [[ $change2 == [yY] ]]; then
				read -p "New directory: " dir
				mkdir -p $dir
			else
				read -p "Directory to export: " dir	
			fi
			
			read -p "Enter network to export to (xxx.xxx.xxx.xxx/XX): " network
			read -p "Enter options (rw,sync,root_squash,no_subtree_check):" options
			
			cat >> /etc/exports <<EOF
$dir $network($options)
EOF
		fi
		
		systemctl restart nfs-server rpcbind
		exportfs -rav
	
		read -p "Do you want to mount it on a distant computer (y/N): " mount
		if [[ $mount == [Yy] ]]; then
		
			read -p "Do you want to export ssh keys before this operation (y/N): " configSSH
			if [[ $configSSH == [Yy] ]]; then
				func_sshKey
			fi

			if [[ -z $dir ]]; then
				read -p "Directory to mount from: " dir
			fi
			
			read -p "Enter distant computer's user: " user
			read -p "Enter distant computer's IP: " IP2
			read -p "Enter distant mountpoint: " mountpoint
			read -p "Enter nfs server's IP: " IP3
			fstab_line="$IP3:$dir $mountpoint	nfs	defaults	0 0"

			ssh -t "$user@$IP2" "
sudo mkdir -p \"$mountpoint\" && \
echo \"$fstab_line\" | sudo tee -a /etc/fstab && \
sudo dnf install -y nfs-utils && \
sudo systemctl enable --now nfs-client.target && \
sudo mount -a
"

		fi

		read -p "Do you want to export another directory (y/N): " change
		
	done
	
	func_menu
}

func_partition() {

	echo ""
	lsblk
	echo ""

	# Ask for disk
	read -p "Enter disk to partition (e.g., /dev/nvme0n2): " disk

	# Check disk exists
	if [[ ! -b "$disk" ]]; then
		echo "ERROR: Disk $disk not found"
		exit 1
	fi

	# Choose partition table type
	echo "Select partition table type:"
	echo "1) GPT (recommended for modern disks)"
	echo "2) MBR (legacy)"
	read -p "Choice [1/2]: " table_choice
	ptable="gpt"
	[[ "$table_choice" == "2" ]] && ptable="msdos"

	# Create partition table
	parted -s "$disk" mklabel $ptable
	echo "Partition table $ptable created on $disk"

	echo ""
	lsblk "$disk"
	echo ""

	# Create new partition
	echo "Creating new partition..."
	echo "Partition types supported: data, swap, EFI, LVM"
	read -p "Enter partition type: " user_type
	read -p "Start (e.g., 0% or 1MiB): " start
	read -p "End (e.g., 100% or 100GiB): " end

	# Map user-friendly type to parted mkpart arguments
	case "$user_type" in
		data) fs="xfs"; pflag="primary" ;;
		swap) fs="linux-swap"; pflag="primary" ;;
		efi) fs="fat32"; pflag="primary" ;;
		lvm) fs="ext4"; pflag="primary" ;;  # partition type for LVM PV
		*) echo "Unknown type $user_type"; exit 1 ;;
	esac

	# Create the partition
	parted -s "$disk" mkpart $pflag $fs "$start" "$end"

	# Set flags for special partitions
	last_part=$(lsblk -nr -o NAME "$disk" | tail -1)
	partition="/dev/$last_part"

	if [[ "$user_type" == "efi" ]]; then
		parted -s "$disk" set $(echo $last_part | grep -o '[0-9]*') boot on
	elif [[ "$user_type" == "lvm" ]]; then
		parted -s "$disk" set $(echo $last_part | grep -o '[0-9]*') lvm on
	fi

	echo "Partition $partition created"
	lsblk "$disk"

	# Format partition if needed
	if [[ "$part_type" != "lvm" ]]; then
		echo ""
		echo "Available filesystems: ext4, xfs, vfat"
		read -p "Filesystem to format: " fs
		if [[ "$fs" == "vfat" ]]; then
			mkfs.vfat "$partition"
		else
			mkfs."$fs" -f "$partition"
		fi
	fi

	# Create mount point
	read -p "Create new directory to mount this partition? (y/N): " ans
	if [[ "$ans" =~ ^[Yy]$ ]]; then
		read -p "New directory path: " dir
		mkdir -p "$dir"
	else
		read -p "Existing directory to mount on: " dir
	fi

	# Get UUID
	uuid=$(blkid -s UUID -o value "$partition" || true)

	# Ask mount options
	if [[ "$part_type" != "lvm" ]]; then
		read -p "Mount options (default: defaults): " options
		options=${options:-defaults}

		# Ask fsck order
		read -p "Filesystem check order (0-skip, 1-root, 2-other) [default 0]: " fsck
		fsck=${fsck:-0}

		# Update fstab
		if [[ -n "$uuid" ]]; then
			grep -q "$uuid" /etc/fstab || \
			echo "UUID=$uuid  $dir  $fs  $options  0 $fsck" | sudo tee -a /etc/fstab
		else
			echo "WARNING: Could not get UUID, skipping fstab entry"
		fi
	fi

	# Reload systemd and mount
	systemctl daemon-reload
	mount -a

	echo ""
	echo "Partition $partition setup complete and mounted at $dir"
	lsblk -f "$disk"

	func_menu
}

func_test() {
	echo "TEST"
	}

func_menu() {

	echo ""
	echo "MENU:"
	echo "	1.  Setup networking"
	echo "	2.  Update dnf packages"
	echo "	3.  Setup hostname"
	echo "	4.  Setup Selinux"
	echo "	5.  Setup firewall-cmd"
	echo "	6.  Setup DHCP Server"
	echo "	7.  Setup DNS Server"
	echo "	8.  Setup Web Server"
	echo "	9a. Setup LDAP Server"
	echo "	9b. Setup LDAP Client"
	echo "	10. Setup SSH keys"
	echo "	11. Setup NFS Server"
	echo "	12. Format new disk"
	echo "	q. Quit"
	echo ""

	read -p "Choose from menu: " choice

	case "$choice" in
		1)
			echo "1. Setup networking"
			func_networking
			;;
		2)
			echo "2. Update dnf packages"
			func_packages
			;;
		3)
			echo "3. Setup hostname"
			func_hostname
			;;
		4)
			echo "4. Setup Selinux"
			func_selinux
			;;
		5)
			echo "5. Setup firewall-cmd"
			func_firewall
			;;
		6)
			echo "6. Setup DHCP Server"
			func_dhcp
			;;
		7)
			echo "7. Setup DNS Server"
			func_dns
			;;
		8)
			echo "8. Setup Web Server"
			func_http
			;;
		"9a")
			echo "9a. Setup LDAP Server"
			func_ldap
			;;
		"9b")
			echo "9b. Setup LDAP Client"
			func_ldapClient
			;;
		10)
			echo "10. Setup SSH keys"
			func_sshKey
			;;
		11)
			echo "10. Setup NFS Server"
			func_nfs
			;;
		12)
			echo "12. Format new disk"
			func_partition
			;;
		[Qq])
			echo "11. Quit"
			exit 1
			;;
		*)
			echo "Invalid option"
			func_menu
			;;
	esac
	}

func_menu
