FROM php:7.0-apache
RUN mkdir /var/www/html/semesterarbeit
COPY *.css /var/www/html/semesterarbeit/
COPY *.html /var/www/html/semesterarbeit/