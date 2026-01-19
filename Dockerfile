FROM ubuntu:22.04
RUN apt update
RUN apt install apache2 -y
ADD . /var/www/html/
ENTRYPOINT apacheclt -D FOREGROUND
