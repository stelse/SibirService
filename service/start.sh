docker build -t perl_db ./database
docker build -t perl_site ./code
docker run --name perl_db -p 5432:5432 -d --rm perl_db
docker run --name perl_site --link perl_db:perl_db -p 8080:8080 -d --rm perl_site

