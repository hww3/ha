#!/bin/sh

OPENHAB_PATH=/var/www/openhab
export OPENHAB_PATH

if [ "x$OPENHAB_ADMIN_PASSWORD" = "x" ] ; then
echo "no admin password specified. aborting."
exit 1
fi
touch /.configuring

grep -v VERIFIED_INSTALLATION /opt/local/etc/pkg_install.conf > pkg_install_noverify.conf
echo "VERIFIED_INSTALLATION=never" >> pkg_install_noverify.conf
pkg_add -C ./pkg_install_noverify.conf http://bill.welliver.org/dist/pkgsrc/SmartOS/2017Q4/x86_64/All/gcc5-libs-5.5.0nb1.tgz 
pkg_delete -f pcre
pkg_add -C ./pkg_install_noverify.conf http://bill.welliver.org/dist/pkgsrc/SmartOS/2017Q4/x86_64/All/pcre-8.41.tgz
pkg_add -C ./pkg_install_noverify.conf http://bill.welliver.org/dist/pkgsrc/SmartOS/2017Q4/x86_64/All/boost-libs-1.65.1nb3.tgz
pkg_add -C ./pkg_install_noverify.conf http://bill.welliver.org/dist/pkgsrc/SmartOS/2017Q4/x86_64/All/yaml-cpp-0.5.3.tgz
pkg_add -C ./pkg_install_noverify.conf http://bill.welliver.org/dist/pkgsrc/SmartOS/2017Q4/x86_64/All/snappy-1.1.7.tgz
pkg_add -C ./pkg_install_noverify.conf http://bill.welliver.org/dist/pkgsrc/SmartOS/2017Q4/x86_64/All/mongodb-3.4.10nb2.tgz
rm pkg_install_noverify.conf

pkgin update
pkgin -y in nginx unzip py27-certbot
pkgin -y in redis git nodejs gmake gcc49

mkdir -p $OPENHAB_PATH 

cd $OPENHAB_PATH && git clone https://github.com/openhab/openhab-cloud.git && \
  chown -R root.root ${OPENHAB_PATH} && \
  find ${OPENHAB_PATH} -type d -exec chmod 555 {} \; && \
  find ${OPENHAB_PATH} -type f -exec chmod 444 {} \;

mv /app.js.patch $OPENHAB_PATH/openhab-cloud
cd $OPENHAB_PATH/openhab-cloud

patch -p1 < app.js.patch
# our patched version for solaris (pr to be submitted)
npm install https://github.com/hww3/node-time.git
npm install

cp /opt/local/etc/nginx/nginx.conf /opt/local/etc/nginx/nginx.conf.orig
mv /ngenix.conf /opt/local/etc/nginx/nginx.conf

mv /config.json ${OPENHAB_PATH}/openhab-cloud

mkdir -p /usr/local/bin
mkdir -p /usr/local/lib/svc/manifest
mkdir -p /usr/local/lib/svc/script

cd /usr/local/bin
wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
/usr/local/bin/certbot-auto --debug

mv /letsencrypt_setup.sh /usr/local/lib/svc/script
mv /letsencrypt_setup.xml /usr/local/lib/svc/manifest
mv /openhab-cloud.xml /usr/local/lib/svc/manifest

chmod 700 /usr/local/lib/svc/script/letsencrypt_setup.sh
svccfg import /usr/local/lib/svc/manifest/letsencrypt_setup.xml
svccfg import /usr/local/lib/svc/manifest/openhab-cloud.xml

/usr/sbin/svcadm disable inetd
/usr/sbin/svcadm disable pfexec
/usr/sbin/svcadm enable redis
/usr/sbin/svcadm enable mongodb

/usr/sbin/svcadm enable -r svc:/local/openhab-cloud:default
/usr/sbin/svcadm enable -r svc:/local/letsencrypt_setup:default
(crontab -l ; echo "51 1,13 * * * /usr/local/bin/certbot-auto renew > /dev/null") | crontab
sleep 5
pkgin -y rm gcc47 gcc49 unzip \
	curl \
	gtar-base \
	less \
	patch \
	sudo \
        diffutils \
        gawk \
        findutils \
        gsed \
        gmake \
        gcc49
pkgin -y ar
rm /.configuring
