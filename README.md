fuel-plugin-external-lb
=======================

**Table of Contents**

  * [Purpose](#purpose)
  * [Compatibility](#compatibility)
  * [How to build plugin](#how-to-build-plugin)
  * [Requirements](#requirements)
  * [Known limitations](#known-limitations)
  * [Configuration](#configuration)
  * [How it works](#how-it-works)
    * [Changes in deployment](#changes-in-deployment)
      * [Default deployment procedure](#default-deployment-procedure)
      * [Deployment with External LB](#deployment-with-external-lb)
    * [Changes in haproxy_backend_status puppet resource](#changes-in-haproxy_backend_status-puppet-resource)
      * [Default deployment procedure](#default-deployment-procedure-1)
      * [Deployment with External LB](#deployment-with-external-lb-1)
  * [How to move controllers to different racks?](#how-to-move-controllers-to-different-racks)
    * [IP traffic flow chart](#ip-traffic-flow-chart)
      * [Default IP flow](#default-ip-flow)
      * [New IP flow with "fake floating network"](#new-ip-flow-with-fake-floating-network)


## Purpose
The main purpose of this plugin is to provide ability to use external load balancer instead of Haproxy which is deployed on controllers.

It can also allow cloud operators to move controllers into different racks (see more details below).

## Compatibility

| Plugin version | Fuel version |
| -------------- | ------------ |
| 1.x.x          | Fuel-8.x     |

## How to build plugin

* Install fuel plugin builder (fpb)
* Clone plugin repo and run fpb there:
```
git clone https://github.com/openstack/fuel-plugin-external-lb
cd fuel-plugin-external-lb
fpb --build .
```
* Check if file `external_loadbalancer-*.noarch.rpm` was created.

## Requirements
External load balancer configuration is out of scope of this plugin. We assume that you configure load balancer by other means (manually or by some other Fuel plugin).

In order to configure your load balancer properly before deployment starts, you can use deployment info provided by Fuel. So you need to:

1. Create new environment
2. Enable plugin
3. Configure your environment (assign roles, networks, adjust settings, etc)
4. Download deployment info with the following CLI command on Fuel node:
```bash
fuel deployment --env 1 --default
```
After this you can open any yaml in `./deployment_1/` directory and check controller management and public IPs in `network_metadata/nodes` hash.

If you want to Public TLS then please note that Fuel generates self-signed SSL certificate during deployment, so you can't download it before deployment starts and configure it on external load balancer. The best solution is to create your own certificate (self signed or issued) and upload it via Environment -> Settings -> Security.

**Important!** It's required to configure mysql-status frontend on external load-balancer (we do not configure such frontend on controllers using Haproxy because we use mysql frontend for that). This frontend should balance 49000 port across all controllers with HTTP chk option. Here's an example of frontend config for Haproxy:

```
listen mysqld-status
  bind 1.1.1.1:49000
  http-request  set-header X-Forwarded-Proto https if { ssl_fc }
  option  httpchk
  option  httplog
  option  httpclose
  server node-1 10.144.2.11:49000 check inter 20s fastinter 2s downinter 2s rise 3 fall 3
  server node-3 10.146.2.11:49000 check inter 20s fastinter 2s downinter 2s rise 3 fall 3
  server node-2 10.145.2.12:49000 check inter 20s fastinter 2s downinter 2s rise 3 fall 3
```

## Known limitations
* OSTF is not working
* Floating IPs are not working if controllers are in different racks

## Configuration
Plugin settings are available on Environment -> Settings -> Other page. Some important notes:
* If external LB is not enabled for one of VIPs (public or management), then Fuel will configure such IP under corosync cluster and setup Haproxy on controllers
* It's possible to specify both FQDN and IP address as external LB host
* It's possible to specify the same external LB host for both public and management VIPs
* If controllers are being deployed in the same rack (network node group), then it's not required to enable "Fake floating IPs"

## How it works
General workflow
* It disables VIP auto allocation in Nailgun which allows us to move controllers into different racks
* It disables VIP deployment and HAproxy configuration on controllers, if operator choses external LB for both public and management VIPs
* It configures “fake floating network” in order to provide access to external networks for OpenStack instances, if operator enables this feature

### Changes in deployment
#### Default deployment procedure
* Run VIPs on controllers
* Setup HAproxy on each controller to balance frontends across all the controllers
* Use `haproxy_backend_status` puppet resource as “synchronization point” in our manifests when we need to wait for some HA frontend to come up (like keystone API)

#### Deployment with External LB
* ~~Run VIPs on controllers~~
* ~~Setup HAproxy on each controller to balance frontends across all the controllers~~
* Use `haproxy_backend_status` puppet resource as “synchronization point” in our manifests when we need to wait for some HA frontend to come up (like keystone API)

### Changes in haproxy_backend_status puppet resource

#### Default deployment procedure
`haproxy_backend_status` puppet resource connects to HAproxy status URL, gets the list of all frontends/backends, finds the needed one and checks if it’s UP or DOWN (`haproxy` provider). Example for keystone-api:

* Connect to http://$LOAD_BALANCER_IP:10000/;csv   ($LOAD_BALANCER_IP = VIP)
* Get list of frontends and check if 'kestone-1' backend is UP

#### Deployment with External LB
`haproxy_backend_status` puppet resource connects to frontend URL directly and checks response HTTP code (`http` provider). Example for keystone-api:

* Connect to http://$LOAD_BALANCER_IP:5000/v3      ($LOAD_BALANCER_IP = External LB)
* Get HTTP responce code and check if it's UP

## How to move controllers to different racks?
In our deployment we use HA resources that are being deployed on controller nodes. Those are mostly services and VIPs.

There are no problems to provide HA for services when we deploy controllers in different racks - we use unicast, so Corosync cluster works fine and provides failover for services without problems.

Providing HA/failover for IPs is the problem here. In case of static routing it’s simply impossible to move IP from one rack to another - such IP won’t be routable anywhere outside its own rack. This problem affects VIPs (services frontends, endpoints) and Floating IPs.

### IP traffic flow chart

#### Default IP flow
This is how ourgoing IP traffic flow look like on controllers
![Default IP flow scheme](doc/default-traffic.png)
![Legend](doc/legend.png)

If controllers are moved to different racks, then everything starting from `br-ex` will be different for every controller - every controller has different public network and IP on `br-ex`. So instances won't be able to access outer networks when public network of controllers that's running neutron-l3-agent does not match with configured floating network.

#### New IP flow with "fake floating network"
In order to solve the issue listed above, plugin configures floating IP gateway in `vrouter` namespace which already exists on every controller. Such configuration will be excatly the same on any controller so it will not matter which controller is running neutron-l3-agent.

![New IP flow scheme](doc/new-traffic.png)
![Legend](doc/legend.png)
