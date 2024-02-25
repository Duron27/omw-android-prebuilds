
# Copy the APK!
sudo docker cp (number of docker):/openmw-0.49.apk openmw.apk

#Delete the docker
sudo docker rmi -f dockerfile .

#Run the docker
sudo docker run -it dockerfile

#Build the docker
sudo docker build -t dockerfile .

#clean all docker hdd eating stuff
sudo docker builder prune
sudo docker image prune
