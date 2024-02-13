just build the docker and when its complete the apk will be inside the docker in root/payload/app/build/Outputs/nightly/debug


#Delete the docker
sudo docker rmi -f dockerfile .

#Run the docker
sudo docker run -it dockerfile

#Build the docker
sudo docker build -t dockerfile .

#clean all docker hdd eating stuff
sudo docker builder prune
sudo docker image prune
