FROM ubuntu:focal
RUN apt-get update
RUN apt-get install -y nginx
WORKDIR /etc/nginx
CMD ["nginx","-g","daemon off;"]
EXPOSE 80