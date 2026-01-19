FROM ubuntu
RUN apt update
RUN apt install apcache2 -y
ADD . /var/www/html/
ENTRYPOINT apcacheclt -D FOREGROUND
