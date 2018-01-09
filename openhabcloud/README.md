# openhabcloud

![](https://i.goopics.net/nI.png)

### What is this ?

OpenHAB Cloud provides remote access to OpenHAB instances

### Features

- With Nginx
- Let's Encrypt setup and configuration (server name must resolve to the container)

### Build-time variables

before creating an instance, you should have a dns cname set up that points to the value you
provide for server_name below. Not only does this direct traffic to your instance, it's also
needed by let's encrypt so that it can verify that you have control over the hostname you're
attempting to secure. triton's container name service allows you to predict the hostname of 
the instance before you create it, so setting up the cname is easy.

example:  

  the uuid of my joyent account is abc
  my instance name is openhabcloud
  my instance is in the us-east-1 datacenter

therefore, the hostname to use in my cname entry would be:

  openhabcloud.inst.abc.us-east-1.triton.zone

so, my cname would look like this:

  server_name IN CNAME openhabcloud.inst.abc.us-east-1.triton.zone

even if i recreate the server instance, as long as i call it the same name, the address will
always point to the ip address of the current instance(s).

now that we've covered that prerequiste, here's how you create the image using hashicorp packer:

packer build  -var-file=local_vars.json -var admin_password=PASSWORD  openhabcloud.packer 

you should copy the local_vars.json.template file to local_vars.json and fill in your joyent account
information. to create an instance from the image you just created, install the triton tool and run it like this:

triton inst create --name openhabcloud -m certbot_email=email_addr -m server_name=server.fqdn openhabcloud_image g4-highcpu-256M

note that you can also use the joyent portal to set this up, but you'll need to make sure you set
the values for certbot_email and server_name before creating the instance... otherwise certbot won't
be able to set up the Let's Encrypt certificates for you, and the webserver will be sad :(

### Ports

- **80** redirects automatically to 443
- **443** ngenix running in front of the cloud app, based on node
- **22** for ssh access

### Additional notes

The app is setup for registration, so that you can register yourself initially. Once you've done that,
you may want to turn off registration. To do that, ssh into the instance (you should have your ssh
key set up in your joyent account):

$ ssh root@myinstanceip
$ vi /var/www/openhab/openhab-cloud/config.json

add the following to the json in this file:
  "registration_enabled": false

for example:

  {
    "registration_enabled": false,
    "system": {
        ......

save the file
restart the app:

$ svcadm disable openhab-cloud
$ svcadm enable openhab-cloud

and you should be good to go.
