#cloud-config
package_update: true
packages:
 - curl
 - wget

mounts: 
- [xvdb, /var/lib/gravity,"auto","defaults", "0", "0"]
- [xvdc, /var/lib/gravity/planet/etcd,"auto","defaults,nofail", "0", "0"]

