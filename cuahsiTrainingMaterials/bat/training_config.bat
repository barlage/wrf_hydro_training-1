cmd /c start PowerShell -Command "docker stop $(docker ps -a -q); docker rm $(docker ps -a -q); docker rmi -f $(docker images -q); docker load -i 'C:/ClassMaterials/docker/dockerImages/wrf_hydro_docker.tar'; docker load -i 'C:/ClassMaterials/docker/dockerImages/rwrfhydro_docker.tar'; docker load -i 'C:/ClassMaterials/docker/dockerImages/wps_docker.tar'"
