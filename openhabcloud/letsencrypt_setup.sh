#!/bin/sh

. /lib/svc/share/smf_include.sh

PATH=$PATH:/opt/local/bin:/opt/local/sbin:/usr/local/bin
#TEST_CERT="--test-cert"
NGINX_ROOT=/opt/local/etc/nginx

export PATH

# don't run the setup process if we are configuring.
if [ -f "/.configuring" ] ; then
  exit 0;
fi

grep "{{SERVER_NAME}}" $NGINX_ROOT/nginx.conf > /dev/null
if [ $? != 0 ] ; then
  echo "INFO: NGINX server already has server name; not configuring."
  exit $SMF_EXIT_OK;
fi

SERVER_NAME=`mdata-get server_name`
CERTBOT_EMAIL=`mdata-get certbot_email`

if [ "x$SERVER_NAME" = "x" ] ; then
  echo "ERROR: Cannot set up SSL without a server_name value. Aborting.";
  exit $SMF_EXIT_ERR_CONFIG;
fi

if [ "x$CERTBOT_EMAIL" = "x" ] ; then
  echo "ERROR: Cannot set up SSL without a certbot_email value. Aborting.";
  exit $SMF_EXIT_ERR_CONFIG;
fi

echo "Setting up NGINX with a certificate for $SERVER_NAME, with $CERTBOT_EMAIL as the admin email."

svcadm disable nginx
sleep 5

# add --staging to the following command during test phases, otherwise
# you are likely to run into let's encrypt time based limits.
su - root /usr/local/bin/certbot-auto certonly --standalone --agree-tos --keep-until-expiring \
  $TEST_CERT -m $CERTBOT_EMAIL -n --no-eff-email -d $SERVER_NAME

if [ -d /etc/letsencrypt/live/$SERVER_NAME ] ; then
sed -e "s/{{SERVER_NAME}}/$SERVER_NAME/" < $NGINX_ROOT/nginx.conf > /tmp/nginx$$.conf
mv $NGINX_ROOT/nginx.conf $NGINX_ROOT/nginx.conf.`date +%Y%m%d%H%M%S`
mv /tmp/nginx$$.conf $NGINX_ROOT/nginx.conf

# strictly speaking, this is the wrooong place for this.
sed -e "s/{{SERVER_NAME}}/$SERVER_NAME/" < /var/www/openhab/openhab-cloud/config.json > /tmp/config$$.json
mv /var/www/openhab/openhab-cloud/config.json /var/www/openhab/openhab-cloud/config.json.`date +%Y%m%d%H%M%S`
mv /tmp/config$$.json /var/www/openhab/openhab-cloud/config.json

echo "Certificates successfully generated. Restarting NGINX."
svcadm clear nginx
sleep 5
svcadm enable nginx

exit $SMF_EXIT_OK
else
echo "Certificates not present in directory. Aborting."
exit $SMF_EXIT_ERR_CONFIG;
fi
