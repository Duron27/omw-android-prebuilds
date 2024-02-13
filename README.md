just build the docker and when its complete the apk will be inside the docker in /root/payload/app/build/outputs/apk/nightly/debug/omw_debug_1.0-46.apk


#Delete the docker
sudo docker rmi -f dockerfile .

#Run the docker
sudo docker run -it dockerfile

#Build the docker
sudo docker build -t dockerfile .

#clean all docker hdd eating stuff
sudo docker builder prune
sudo docker image prune
