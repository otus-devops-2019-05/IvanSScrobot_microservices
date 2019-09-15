build : blackboxexporter_build mongoexporter_build prometheus_build ui comment post alertmanager_build
push : blackboxexporter_push mongoexporter_push prometheus_push ui_push comment_push post_push alertmanager_push

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

alertmanager_build : 
	docker build -t $(USER_NAME)/alertmanager ./alertmanager
alertmanager_push : 
	docker push $(USER_NAME)/alertmanager	

ui : 
	echo `git show --format="%h" HEAD | head -1` > ../src/ui/build_info.txt
	echo `git rev-parse --abbrev-ref HEAD` >> ../src/ui/build_info.txt
	docker build -t $(USER_NAME)/ui ../src/ui/
ui_push : 
	docker push $(USER_NAME)/ui

comment : 
	echo `git show --format="%h" HEAD | head -1` > ../src/comment/build_info.txt
	echo `git rev-parse --abbrev-ref HEAD` >> ../src/comment/build_info.txt
	docker build -t $(USER_NAME)/comment ../src/comment/
comment_push : 
	docker push $(USER_NAME)/comment

post : 
	echo `git show --format="%h" HEAD | head -1` > ../src/post-py/build_info.txt
	echo `git rev-parse --abbrev-ref HEAD` >> ../src/post-py/build_info.txt
	docker build -t $(USER_NAME)/post ../src/post-py/
post_push : 
	docker push $(USER_NAME)/post