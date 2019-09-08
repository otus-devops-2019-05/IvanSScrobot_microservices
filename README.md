# IvanSScrobot_microservices

## HW#16 monitoring-1

https://devconnected.com/mongodb-monitoring-with-grafana-prometheus/
https://github.com/percona/mongodb_exporter



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
