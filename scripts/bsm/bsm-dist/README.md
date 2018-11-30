### PURPOSE

This program helps to inspect, run, or stop the following services
for local development:

##### Supported services
* redis service on port 6379
* mongod service on port 27017
* the reverse http-proxy on port 4000
* the rails server on port 5000
* the polymer-app on port 8500
* the polymer-website on port 8510

##### Future supported services (if possible)
* serviceworker service
* sidekiq
* puma or other rails plugins


---
### SETUP
* rename the `bsm/bsm-dist/lib/LOCAL` file as:
  + `bsm/bsm-dist/lib/local.sh`
* edit any variables in this new `local.sh` file to reflect the environment on your local development machine.
* if necessary change the permissions of the setup file `setup.sh`:
  + `chmod u+x setup.sh`
* execute the `setup.sh` file
  + `./setup.sh`


---
### REFERENCES
* port 4000 shows up as `*:terabase` [see here](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?&page=76)
* port 5000 shows up as `*:commplex-main` [see here](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?&page=87)
* port 8500 shows up as `localhost:fmtp` [see here](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?&page=111)


