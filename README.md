# IvanSScrobot_microservices

## HW#14 Docker. Practice #4

**1. Preparations and the main task:**

Try running containers in "none" network and in "host" one:
```
 docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig 
 docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig 
 ```
Then, create "bridge"-network: `docker network create reddit --driver bridge `. For orgaizing a subnet, use ` --subnet=10.0.2.0/24` option. In order to add a container into several networks, use ` docker network connect front_net post`. 

Bridge-utils helps to learn more about networks on a host (`docker network ls`, `brctl show <interface> `).

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
