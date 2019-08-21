# IvanSScrobot_microservices


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
