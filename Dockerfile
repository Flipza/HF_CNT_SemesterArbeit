FROM php:7.0-apache
RUN mkdir /var/www/html/servicetool
COPY *.css /var/www/html/servicetool/
COPY *.html /var/www/html/servicetool/
