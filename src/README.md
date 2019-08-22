# Micorservices


docker network create reddit
docker run -d --network=reddit --network-alias=post_db --network-alias=mongo_db mongo:latest
docker run -d --network=reddit --network-alias=post ivansscrobot/post:1.0
docker run  -e COMMENT_DATABASE_HOST='mongo_db' -d --network=reddit --network-alias=comment ivansscrobot/comment:1.0
docker run -d --network=reddit -p 9292:9292 ivansscrobot/ui:1.0

Note: Make sure put the container name after the environment variable, not before that.