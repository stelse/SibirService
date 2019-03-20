FROM debian:latest

RUN apt update -qq
RUN apt install -y postgresql
RUN apt install -y libpq-dev
RUN apt install -y build-essential 

RUN cpan threads
RUN cpan YAML
RUN cpan Algorithm::LCSS 
RUN cpan Data::Dumper 
RUN cpan DBI
RUN cpan DBD::Pg
RUN cpan Try::Tiny
RUN cpan List::MoreUtils

RUN mkdir -p /home/app/files/

WORKDIR /home/app/

COPY index.pl .

CMD perl index.pl
