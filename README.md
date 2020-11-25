# Description
Will be used for storing configs or usable scripts to support Nomad and Consul High Availability
# Pre-requisites
## AWS
* Set IAM Role with Policy to describe instances
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "ec2:DescribeInstances",
            "Resource": "*"
        }
    ]
}
```
* All VMs must have tag (in this script `tipeserver:nomad`). And also must be bound with IAM role above
# Notes
Change the DNS2 to your DNS gateway. Let's say your VPC is 172.25.0.0/16, then the DNS will be 172.25.0.2.
# Tested
* AWS with Amazon 2 as Image
# Post Request
* Setup NFS -> https://medium.com/@admantium/persisting-data-with-nomad-f98754753c0e
* For LB -> https://learn.hashicorp.com/tutorials/nomad/load-balancing-traefik?in=nomad/load-balancing
# DNSMasq Config
To allow request from public. the `/etc/dnsmasq.conf` file must have only this directive
```
conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig
```
