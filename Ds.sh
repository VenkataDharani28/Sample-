docker run -it my-container /bin/bash /path/to/script.sh

#####$$
docker cp script.sh container_id:/script.sh
docker exec -it container_id /bin/bash /script.sh
######

FROM ubuntu:latest

# Copy the script into the container
COPY script.sh /script.sh
###$$$######
# Grant execute permissions
RUN chmod +x /script.sh
###########
# Run the script on container startup
CMD ["/bin/bash", "/script.sh"]
Then, build and run the container:
docker build -t my-container .
docker run -it my-container

###########
ENTRYPOINT ["/bin/bash", "/script.sh"]
