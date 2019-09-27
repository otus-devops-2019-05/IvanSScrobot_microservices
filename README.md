# IvanSScrobot_microservices

## HW#18 logging-1

**1. Preparations and the main task:**

Create a new host in GCE:
```
$ docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-open-port 5601/tcp \
    --google-open-port 9292/tcp \
    --google-open-port 9411/tcp \
    logging

$ eval $(docker-machine env logging)
```
In ./docker/docker-compose-logging.yml describe our 'logging infrastructure', which is Fluentd + ElasticSearh + Kibana. In ./logging/fluentd put fluent.conf and Dockerfile for the fluentd image. [An article](https://habr.com/ru/company/selectel/blog/250969/) about Fluentd basics on Habr.com. [Docs](https://docs.fluentd.org/filter/parser) for FluentD parser plugin.

**2. Task with \*: parallel parsing logs in FluentD**

Tricky task. In v0.12 this structure works, but it may not be suitable for other versions:
```
<filter service.ui>
  @type parser
  key_name message
  format grok
  <grok>
    pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  </grok>
  <grok>
    pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IP:remote_addr} \| method=%{GREEDYDATA:method} \| response_status=%{INT:response_status}
  </grok>
</filter>
```

See Grok datatypes [here](https://streamsets.com/documentation/controlhub/latest/help/datacollector/UserGuide/Apx-GrokPatterns/GrokPatterns_title.html).

**3. Task with \*: Zipkin**

Download "broken application" by running command `svn export https://github.com/Artemmkin/bugged-code/trunk/`. Then, in ./docker/.env change UI_TAG from 'logging to 'latest', add environments in ./docker/docker-compose.yml, rebuild docker images in ./src, and set up the whole app by running `docker-compose up -d`.

In zipkin I can see that the longest span is one named "post: db_find_single_post".  Look up for this: `find ./ -type f -exec grep -H 'db_find_single_post' {} \;`, and find it in `./post-py/post_app.py`. Finally, in this file find the line `time.sleep(3)` - the very cause of the problem.



## HW#17 monitoring-2

**1. Preparations and the main task:**

Install [cAdvisor](https://github.com/google/cadvisor) - running daemon that collects and provides information about docker containers. Add new section into `scrape_configs` part of prometheus.yml:
```
- job_name: 'cadvisor'
    static_configs:
      - targets:
        - 'cadvisor:8080'
```

__[Grafana](https://grafana.com/)__

Add a new container in docker-compose-monitoring.yml:
```
grafana:
    image: grafana/grafana:5.0.0
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secret
    depends_on:
      - prometheus
    ports:
      - 3000:3000
```
Add prometheus as a datasource and import dashboards from https://grafana.com/grafana/dashboards. Then, create couple dashboards and tweak them (use functions 'rate()', 'histogram_quantile()'). 

Build a new container for __[Alertmanager](https://prometheus.io/docs/alerting/alertmanager/)__ (additional component for Prometheus):
```
FROM prom/alertmanager:v0.14.0
ADD config.yml /etc/alertmanager/
```
In config.yml for alertmanager, define notifications to my Slack channel (use Slack Incoming Webhooks). In .\monitoring\prometheus\alerts.yml define rules for alerts, and in prometheus.yml add kinda link to these alert rules:
```
rule_files:
  - "alerts.yml"
```
That's it, now just rebuild and redeploy containers running `docker-compose up -d`.

**2. Task with \*: scrape metrics from Docker directly and with Telegraf**

Add building and pushing Alertmanager image in my Makefile:
```
alertmanager_build : 
	docker build -t $(USER_NAME)/alertmanager ./alertmanager
alertmanager_push : 
	docker push $(USER_NAME)/alertmanager	
```  

Collect Docker metrics with Prometheus directly, using [Docker experimental mode](https://docs.docker.com/config/thirdparty/prometheus/). Add new job 'docker' in prometheus.yml and in /etc/docker/daemon.json past following:
```
{
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
```
At this time, cAdviser wins 'docker as direct Prometheus target' hands down. The latter provides a few confusing metrics, and it's still not recommended for production.

__[Telegraf](https://grafana.com/)__

Telegraf collects various metrics and provide them for different systems. It has [docker input](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/docker) and [Prometheus output](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/prometheus_client) (also, see docs [here](https://docs.docker.com/samples/library/telegraf/)). In a nutshell, we describe inputs and outputs in telegraf.conf:
```
[[outputs.prometheus_client]]
    listen = ":9273"
[[inputs.docker]]
     endpoint = "unix:///var/run/docker.sock"
``` 
and add 'telegraf' job in prometheus.yml:
```
- job_name: 'telegraf'
    static_configs:
      - targets:
        - 'telegraf:9273'
```

-----------------
Если будет желание вернуться к заданию с Autoheal-ом, то в его репозитории есть примеры работы с заглушкой AWX-а: https://github.com/openshift/autoheal/tree/master/examples

## HW#16 monitoring-1

**1. Preparations and the main task:**
Create a new instance in GCE and install there docker-machine. Inside the instance, run Prometheus in a container:
```
docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus:v2.1.0 
```
Make our own docker image based on `prom/prometheus:v2.1.0 ` and add prometheus.yml in /etc/prometheus/. Rebuild our applications (ui, post-py, comment) and run them with docker-compose. Since the apps provide /metrics in the proper format (e.g. http://35.205.31.224:9292/metrics), Prometheus scrapes them without any additional exporters. Also, install [node exporter](https://github.com/prometheus/node_exporter) in order to collect OS metrics.

**2. Task with \*:  add MongoDB exporter**

I downloaded the latest release of [mongodb_exporter](https://github.com/percona/mongodb_exporter), just because I didn't find anything else for this purpose, and run it a dedicated container (Dockerfile is in ./monitoring/mongoexporter/). Mongodb_exporter uses 9216 port by default, so add following code in prometheus.yml:
```
- job_name: 'mongo'
    static_configs:
      - targets:
        - 'mongo-exporter:9216'
```

NB - don't forget about `ENV MONGODB_URI='mongodb://post_db:27017'`, which passes the exporter the address of MongoDB installation.

**3. Task with \*:  add Blackbox exporter**

Again, download the latest release from [github](https://github.com/prometheus/blackbox_exporter), run it in another container, the Dockerfile is in ./monitoring/blackboxexporter/. `blackbox.yml` is responsible for the exporter configuration. In my case, it's needed to switch IP protocol to the 4th version:
```
modules:
  http_2xx:
    prober: http
    http:
      method: GET
      preferred_ip_protocol: ip4
  icmp:
    prober: icmp
    icmp:
      preferred_ip_protocol: ip4   
```
Also, it's worth mentioning that in prometheus.yml I have to write a separate section for every 'prober'. For example, below is the job for the ICMP probe which pings two targets:
```
  - job_name: 'blackbox_icmp'
    metrics_path: /probe
    params:
      module: [icmp]
    static_configs:
      - targets: 
        - comment
        - post
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115 # Blackbox exporter.
```

**4. Task with \*:  create Makefile for all docker images I used**

My Makefile is in the ./monitoring. If `make` is run without arguments, it builds all needed images. Also, it can be run as `make push` for pushing all images on Docker Hub. As I didn't implement Docker Hub autorization inside Makefile, it should be done before running the `make` command. Below is the part of Makefile:
```
build : blackboxexporter_build mongoexporter_build prometheus_build ui comment post
push : blackboxexporter_push mongoexporter_push prometheus_push ui_push comment_push post_push

.PHONY : build

USER_NAME := ivansscrobot

blackboxexporter_build : 
	docker build -t $(USER_NAME)/blackbox ./blackboxexporter
blackboxexporter_push : 	
	docker push $(USER_NAME)/blackbox

mongoexporter_build : 	
	docker build -t $(USER_NAME)/mongoexporter ./mongoexporter
mongoexporter_push :	
	docker push $(USER_NAME)/mongoexporter

prometheus_build : 
	docker build -t $(USER_NAME)/prometheus ./prometheus
prometheus_push : 
	docker push $(USER_NAME)/prometheus
  ```

## HW#15 Gitlab-ci

**1. Preparations and the main task:**

Create a new instance in GCE and install Gitlab using [Omnibus package](https://docs.gitlab.com/omnibus/README.html). I use an ansible playbook (./gitlab/ansible/gitlab-install.yml) along with [gcp_compute](https://docs.ansible.com/ansible/latest/plugins/inventory/gcp_compute.html). The same playbook is responsible for the installation of ansible-runner. 

In gitlab-ci.yml define ci pipeline (simple one, just to go through main features). It works after a commit to the gitlab repo is made, don't forget add this additional repo and push in it:
```
 git remote add gitlab http://<your-vm-ip>/homework/example.git 
 git push gitlab gitlab-ci-1
 ``` 
Then, create gitlab runner inside a Docker container ([docs here](https://docs.gitlab.com/runner/install/docker.html)), and register a runner:
```
docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest 

docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
```
**2. Task with \*: in gitlab pipeline, build a container with our app**

There are 3 ways to build a docker container inside a gitlab docker which runs a job (see [doc](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html)). I used Docker socket binding. In this case, you don’t need to include the `docker:dind` service as when using the Docker in Docker executor. All you need is to register a runner properly:

```
sudo  docker exec -it gitlab-runner gitlab-runner registerr -n \
  --url http://104.198.248.218/ \
registration-token e8pyXzxMY8XTDxYZ5eDz\
  --executor docker \
  --description "Runner" \
  --docker-image "alpine:latest" \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock  \
  --run-untagged \
  --locked=false
```
*(the key option here is --docker-volumes)

Then, add necessary instructions in .gitlab-ci.yml file. Look at examples in .gitlab-ci-additional_task.yml file: in build_job gitlab-ci makes an image and in branch_review runs an actual container.

**3. Task with \*: automate installation and registering dozens of gitlab-ruuners**

I divided this task into two parts:
- creating GCE instances by Terraform and auto-deploying runners by Ansible
- [autoscaling](https://docs.gitlab.com/runner/configuration/autoscale.html#overview)
 
The first part is pretty straightforward: I use terraform for creating instances in my GCE project (directory 'terraform', variable node_count manages the number of instances) and Ansible for deploying gitlab-runners into the instances. inventory.compute.gcp.yml in directory ansible provides me with a dynamic inventory. As for Ansible, the easiest way I managed to find is to use a fully-fledged ready-to-cooK role [riemers.gitlab-runner](https://github.com/riemers/ansible-gitlab-runner) (instead of programming my own). Variables for the role are in ./ansible/vars/gitlab-runner-vars.yml, playbook is in ./ansible/gitlab-runner.yml

Autoscaling, on the other hand, took me 3 days to compel gitlab to work in accordance with [this article](https://verkoyen.eu/blog/2018/08/scaling-gitlab-runner-on-google-cloud-platform), [this article](https://docs.gitlab.com/runner/executors/docker_machine.html#preparing-the-environment), and this [official doc](https://docs.gitlab.com/runner/configuration/autoscale.html). At first, I tried to run 'bastion' runner inside the docker container that I made earlier, see '1. Preparations and the main task' or [Run GitLab Runner in a container](https://docs.gitlab.com/runner/install/docker.html). I gave up in despair and install runner as a server with no wrapper around, but it didn't work either. Then, [here](https://forum.gitlab.com/t/failed-to-update-executor-docker-machine-for-9fb5fe99-no-free-machines-that-can-process-builds/3011/3) I found out this: 
```
since I have to invoke gitlab-runner as root using sudo, it also seems to create images using docker-machine as root as well, which makes the machines “invisible” to docker-machine when run as another user. It’s notable that the recommendations from docker seem to be never to run docker-machine as root. 
```
I started my gitlab-runner manually and - hurray! - it worked. My config.toml file (can be found in /srv/gitlab-runner/ or ~/.gitlab-runner/ looks like:

```
concurrent = 5
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "runner2"
  url = "http://104.198.248.218/"
  token = "Js-XFh_VyzvrJTPx9Gi9"
  executor = "docker+machine"
  [runners.custom_build_dir]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
 [runners.machine]
    IdleCount = 0
    IdleTime = 600
    MachineDriver = "google"
    MachineName = "auto-scale-runner-%s"
    MachineOptions = [
      "google-project=docker-is",
      "google-machine-type=f1-micro",
      "google-tags=gitlab-ci-slave",
      "google-preemptible=true",
      "google-zone=europe-west1-c",
      "google-use-internal-ip=true",
      "google-machine-image=coreos-cloud/global/images/family/coreos-stable"
    ]
```
Also, keep in mind that 'bastion' runner has to be registered with `--executor docker+machine` and docker-machine needs to know where to find credentials fot GCE, so create a proper .json file and run `export GOOGLE_APPLICATION_CREDENTIALS=$HOME/gce-credentials.json`. By the way, for some reason, authentication didn't occur automatically via the built-in service account (as it described in [doc](https://docs.docker.com/machine/drivers/gce/)). 

I didn't dive deeper and didn't combine autoscaling with auto-deploying.

**4. Task with \*: integrate slack with gitlab**

Just follow the official [documentation](https://docs.gitlab.com/ee/user/project/integrations/slack.html). The link to my Slack channel: https://app.slack.com/client/T6HR0TUP3/CKP31NMN3



## HW#14 Docker. Practice #4

**1. Preparations and the main task:**

Try running containers in "none" network and in "host" one:
```
 docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig 
 docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig 
 ```
Then, create "bridge"-network: `docker network create reddit --driver bridge `. For orgaizing a subnet, use ` --subnet=10.0.2.0/24` option. In order to add a container into several networks, use ` docker network connect front_net post`. 

Bridge-utils helps to learn more about networks on a host (`docker network ls`, `brctl show <interface> `, `iptables -nL -t nat`).

**Docker-composer**

Install with pip, official docs is [here](https://docs.docker.com/compose/). Write docker-compose.yml, export variables `export VARIABLE_NAME=<variable-value>`. Variables also can be placed in *`.env`* file. Docker-compose with aliases and additional variables looks something like this:
```
version: '3.3'
services:
  post_db:
    image: mongo:3.2
    volumes:
      - post_db:/data/db
    networks:
      - back_net
  ui:
    build: ./ui
    image: ${USERNAME}/ui:${UI_VERSION}
    ports:
      - ${APP_PORT}:9292/tcp
    networks:
      - front_net
  post:
    build: ./post-py
    image: ${USERNAME}/post:${VERSION}
    networks:
      - front_net
      - back_net
  comment:
    build: ./comment
    image: ${USERNAME}/comment:${VERSION}
    networks:
      - front_net
      - back_net

volumes:
  post_db:

networks:
  back_net:
  front_net:
  ```

Containers and app’s network are given a name based on the “project name”, which is based on the name of the directory it lives in ("src" in our case). It's possible to override the project name with either the `--project-name` flag or the `COMPOSE_PROJECT_NAME` environment variable.

**2. Additional tasks with \*:**

docker-compose.override.yml can customize an environment (check [docs](https://docs.docker.com/compose/extends/)). In our case, it may look like:
```
version: '3.3'

services:
  ui:
    #volumes:
    #    - "./ui:/app"
    command: "puma --debug -w 2"    
```
Volumes section is commented here as we run all command through docker-machine, `docker-compose up` is running on the remote host, and files from local path `"./ui/"` can't be mounted  there.

## HW#13 Docker. Practice #3.

**1. Preparations and the tasks (including those with \*):**

Decompose our applivcation into 3 components, write Dockerfile for each of them. Create a bridge-network for the new containers, start containers with network aliases. Below commands for starting containers with alternative aliases, which in our case requires environment variables passed to docker:
```
docker network create reddit
docker run -d --network=reddit --network-alias=post_db --network-alias=mongo_db mongo:latest
docker run -d --network=reddit --network-alias=post ivansscrobot/post:1.0
docker run  -e COMMENT_DATABASE_HOST='mongo_db' -d --network=reddit --network-alias=comment ivansscrobot/comment:1.0
docker run -d --network=reddit -p 9292:9292 ivansscrobot/ui:1.0
```
**Note: Make sure put the container name after the environment variable, not before that.**

Improve Dockerfile for ui part of the applications in order to make it smaller. I used `FROM ruby:2.4.6-alpine3.10` since this image is pretty light and has pre-installed packages for ruby.

Use docker volume for Mongo:
```
docker volume create reddit_db
docker run -d --network=reddit --network-alias=post_db \
--network-alias=comment_db -v reddit_db:/data/db mongo:latest
```
Now we can kill containers ` docker kill $(docker ps -q)` and posts in the database will be saved.


## HW#12 Docker. Practice #2.

**1. Preparations and the main task:**

Install docker (see [here](https://docs.docker.com/install/linux/docker-ce/centos/)). Run simple containers, attach, run `docker -it exec my_container bash`, look at the list of images, etc. etc. - docker cheatsheet is [here](https://medium.com/statuscode/dockercheatsheet-9730ce03630d). Also looked at the official [get started guide](https://docs.docker.com/get-started/).

Create an image from container by running `docker commit <u_container_id> yourname/ubuntu-tmp-file` and save output of `docker images` into docker-1.log. Also, write a short explanation of differences between a docker image and a container in that file.

Create a new GCE project, install Gcloud SDK, configure it, authorize. 

Install [docker machine](https://docs.docker.com/machine/install-machine/). Main command: docker machine create _name_, eval $(docker-machine env _name_) (switch to a remote docker host),  eval $(docker-machine env --unset) (switch to a local docker), docker-machine ls, docker-machine rm _name_

Example with GCP:
```
docker-machine create --driver google  --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20190813a --google-machine-type n1-standard-1  --google-zone europe-west1-b  docker-host
```
This command `gcloud compute images list --uri` shows the list of available images from Google. 

Then, make Dockerfile, config files for mongoDB and starting script, and build an image: ` docker build -t reddit:latest .`. Run a new container: docker run --name reddit -d --network=host reddit:latest`. Finally, publish the image on Docker Hub: `docker tag reddit:latest ivansscrobot/otus-reddit:1.0`.

**2. Additional tasks with \*:**

- Create instances in GCP with Terraform (just to recap: describe the infrastructure in main.tf, describe variables along with their default values in variables.tf, describe actual values of variables in terraform.tfvars, and describe IP addresses of my instances in outputs.tf). The number of instances is defined in variables.tf:
```
variable node_count {
  description = "Number of VM"
  default     = 2
}
```
- Make ansible dynamic inventory by using [gcp_compute inventory plugin](https://github.com/ansible/ansible/blob/devel/lib/ansible/plugins/inventory/gcp_compute.py) (configured by `inventory.compute.gcp.yml` file in my case). Process of Installation and setup is described [here](http://matthieure.me/2018/12/31/ansible_inventory_plugin.html). 
Don't forget that `service_account_file.json` contains my private key and, therefore, has to be mentioned in .gitignore for the safety reasons!

- Write Ansible playbook to install Docker, download and run my image (from Docker Hub). My playbook is in docker.yml, [here](https://docs.ansible.com/ansible/2.6/modules/docker_image_module.html#docker-image-module) the official doc for docker_image and [here](http:// anddocs.ansible.com/ansible/latest/modules/docker_container_module.html) - for docker_container ansible module. In docker_container section, don't forget to start my starting script:
```
    docker_container:
        name: "{{ default_container_name }}"
        image: "{{ default_container_image }}"
        state: started
        tty: yes
        ports:
        - "9292:9292"
        command: /start.sh
```

Look at logs with the help of `docker logs reddit -f`, don't forget to use this command `docker-machine ssh docker-host` in order to connect to the machine's host, and run `docker exec -it reddit bash` on the remote host in GCP in order to inspect processes or to restart puma.

- Make packer template `packer_docker.json` and describe packer's variables in `packer_variables.json` to make an image with docker installed inside. 
