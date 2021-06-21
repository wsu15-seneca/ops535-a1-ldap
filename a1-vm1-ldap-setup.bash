#!/usr/bin/env bash
# OPS535 Assignment -Script for remote deployment of an OpenLDAP server
# Written by: Eliza Su
# Last Modified Jun 21, 2021
# Run script on VM1 (router) and remote VM4 (rns-ldap)
# Subject: LDAP server setup
# Prepre files: mdb-conf.ldif, mdb-conf-a.ldif, migrate_common.h, migrationtools.tgz, base.ldif, people.ldif, group.ldif, add_certs.ldif

echo
echo "Investigation 1: OpenLDAP Server Setup and Configuration"
echo
echo "# Step 1  Install yum-utils"
yum install -y yum-utils
echo

echo "# Step 2  Install the symas ldap repo"
yum-config-manager --add-repo=https://repo.symas.com/configs/SOFL/rhel8/sofl.repo
echo

echo "# Step 3  Install package: openldap"
yum install -y openldap
echo

echo "# Step 4  Install package: symas-openldap-clients"
yum install -y symas-openldap-clients
echo

echo "# Step 5  Install package: symas-openldap-servers"
yum install -y symas-openldap-servers
echo

echo "# Step 6  Install package: perl"
yum install -y perl
echo

echo "# Step 7  Install: tar"
yum install -y tar
echo

echo "# Step 8  Extra a package called 'migrationtools' to usr/share/"
tar -zxvf /home/student/ops535/a1/migrationtools.tgz -C /usr/share/
echo

echo "# Step 9  Verify that the directory for storing the OpenLDAP database (/var/lib/ldap) is owned by ldap:ldap. "
ls -al /var/lib/
echo

echo "# Step 10 Verify that the core schema file (/etc/openldap/slapd.d/cn=config/cn=schema) is owned by ldap:ldap."
ls -al /etc/openldap/slapd.d/cn=config
echo

echo "# Step 11 Start the ldap service (slapd), and ensure that it will automatically start when your machine boots."
systemctl start slapd
systemctl enable slapd
systemctl is-active slapd
echo

echo "# Step 12 Use the ldap add command to add the cosine, nis, and inetorgperson schemata to your server in that order. "
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
echo

echo "# Step 13 Set ldap administrator (RootDN) password: ldap**"
slappasswd > /home/student/ops535/a1/slappasswd2.txt

echo "# Step 14 Insert your new password into the following ldif file, and apply it to your database with the ldapmodify command."
echo "olcRootPW: " > /home/student/ops535/a1/slappasswd1.txt
paste -d "" /home/student/ops535/a1/slappasswd1.txt /home/student/ops535/a1/slappasswd2.txt >> /home/student/ops535/a1/mdb-conf.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /home/student/ops535/a1/mdb-conf.ldif
ldapsearch -x -b '' -s base '(objectClass=*)' namingContexts

echo
echo "# Step 15 Create an LDIF file (base.ldif) for the base context wsu15.ops entry to be added to the OpenLDAP directory. "
ldapadd -x -D "cn=Manager,dc=wsu15,dc=ops" -W -f /home/student/ops535/a1/base.ldif
ldapsearch -x -b 'dc=wsu15,dc=ops' '(objectClass=*)'
echo

echo "# Step 16 Create an LDIF file (people.ldif) for the People container to be added to the OpenLDAP directory."
ldapadd -x -D "cn=Manager,dc=wsu15,dc=ops" -W -f /home/student/ops535/a1/people.ldif
ldapsearch -x -b 'dc=wsu15,dc=ops' '(objectClass=*)'
echo

echo "# Step 17 Apply the above two ldif files to the ldap database."
cp /home/student/ops535/a1/migrate_common.ph /usr/share/migrationtools/migrate_common.ph 
echo


echo "# Step 18 Create two new users (ldapuser3 and ldapuser4) on your machine, and set their passwords."
mkdir /home1
useradd -b /home1 -m ldapuser3
passwd ldapuser3
useradd -b /home1 -m ldapuser4
passwd ldapuser4
chmod 777 /home1/ldapuser3
chmod 777 /home1/ldapuser4
echo

echo "# Step 19 Use the migrate_passwd.pl file to convert the user information you extracted earlier into an ldif file"
grep -w ldapuser3 /etc/passwd > /home/student/ops535/a1/ldapusers.entry
grep -w ldapuser3 /etc/passwd >> /home/student/ops535/a1/ldapusers.entry
cat /home/student/ops535/a1/ldapusers.entry
echo

echo "# Step 20 Create an ldif file called group.ldif that will add an organizational unit with the distinguished name ou=Group, dc=wsu15, dc=ops. It will act as an organizer for group information."
/usr/share/migrationtools/migrate_passwd.pl /home/student/ops535/a1/ldapusers.entry /home/student/ops535/a1/ldapusers.ldif
ldapadd -x -D "cn=Manager,dc=wsu15,dc=ops" -W -f /home/student/ops535/a1/ldapusers.ldif
ldapsearch -x -b 'dc=wsu15,dc=ops' '(objectClass=*)'
echo

echo "# Step 21 Use the /etc/group file and migrate_group.pl to create an ldif file that will add the group entries for ldapuser1 and ldapuser2 to the database."
ldapadd -x -D "cn=Manager,dc=wsu15,dc=ops" -W -f /home/student/ops535/a1/group.ldif
ldapsearch -x -b 'dc=wsu15,dc=ops' '(objectClass=*)'
echo

echo "# Step 22 Add the group entries for ldapuser3 and ldapuser4 to your database. Use ldapsearch to confirm that they have been added."
grep -w ldapuser3 /etc/group > /home/student/ops535/a1/ldapgroups.entry
grep -w ldapuser4 /etc/group >> /home/student/ops535/a1/ldapgroups.entry
/usr/share/migrationtools/migrate_group.pl ldapgroups.entry /root/ldapgroups.ldif
ldapadd -x -D "cn=Manager,dc=ops535,dc=com" -W -f /home/student/ops535/a1/ldapgroups.ldif
ldapsearch -x -b 'dc=wsu15,dc=ops' '(objectClass=*)'
echo

echo "# Step 23 Modify the firewall to allow incoming ldap traffic from the work zone. Make sure that this change persists past reboot."
firewall-cmd --add-service=ldap --permanent --zone=work
firewall-cmd --reload
firewall-cmd --list-all --zone=work
echo

echo
echo "Investigation 2: Modifying OpenLDAP Server Configuration to use TLS"
echo
echo "# Step 24 Install the openssl package"
yum group install 'Development Tools' -y
yum install perl-core zlib-devel -y
echo

echo "# Step 25 Run the following commands to create a self-signed TLS certificate for your server (make sure to replace the values with ones from the machine)"
openssl genrsa -des3 -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.cert.pem
openssl genrsa -out rns-ldap.wsu15.ops.key 4096
openssl req -new -key rns-ldap.wsu15.ops.key -out rns-ldap.wsu15.ops.csr
openssl x509 -req -in rns-ldap.wsu15.ops.csr -CA ca.cert.pem -CAkey ca.key -out rns-ldap.wsu15.ops.crt -CAcreateserial -days 365 -sha256

echo "# Step 26 Copy the certificate, the private key, and the certificte authority file to an appropriate directory (make sure the directory and the files in it are owned by the ldap account and that the directory has permissions set to 0700 and the files have 0600)"
chmod 0700 /etc/openldap/certs/
chown ldap:ldap /etc/openldap/certs/certs
cp rns-ldap.wsu15.ops.crt rns-ldap.wsu15.ops.key /home/student/ops535/a1/
cp rns-ldap.wsu15.ops.crt rns-ldap.wsu15.ops.key ca.cert.pem /etc/openldap/certs/
chmod 0600 /etc/openldap/certs/*.*
chown ldap:ldap /etc/openldap/certs/*.*
echo
echo "ls al /etc/openldap/"
ls -al /etc/openldap/
echo
echo "ls al /etc/openldap/certs/"
ls -al /etc/openldap/certs/

echo
echo "# Step 27 Write an ldif file and add the following values to dn: cn=config (again making sure to put in values from the own machine)"
ldapmodify -Y EXTERNAL -H ldapi:/// -f /home/student/ops535/a1/add_certs.ldif

echo "# Step 28 Use slapcat to ensure they are set correctly"
slapcat -b "cn=config" | egrep "Certificate(Key)?File"

echo
echo "# Step 29 Update /etc/openldap/ldap.conf to locate the CACERT, and to indicate that ldaps is now allowed"
cp /home/student/ops535/a1/ldap.conf /etc/openldap/ldap.conf 

echo
echo "# Step 30 Update your firewall to permanently allow ldaps instead of ldap."
firewall-cmd --remove-service=ldap --permanent --zone=work
firewall-cmd --add-service=ldaps --permanent --zone=work
firewall-cmd --reload
firewall-cmd --list-all --zone=work

echo "# Step 31 Check that you can still use ldapsearch before continuing to the next investigation."
ldapsearch -x -b 'dc=wsu15,dc=ops' '(objectClass=*)'

echo "# Step 32 save the script to ~student/ops535/a1/scripts/a1-vm1-ldap.bash"
cd /home/student/ops535/a1
mkdir scripts
cp /home/student/ops535/a1/a1-vm1-ldap.bash ~student/ops535/a1/scripts/a1-vm1-ldap.bash
echo "ls ~student/ops535/a1/scripts/"
ls ~student/ops535/a1/scripts/ -al
echo