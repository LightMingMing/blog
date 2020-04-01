## Docker

```bash
# A self-sufficient runtime for containers
docker --help
docker command --help
```



```bash
# List containers
docker ps [-a | -l]

# Remove one or more containers
docker rm [-f] CONTAINER [CONTAINER...]

docker start | stop | restart [OPTIONS] CONTAINER [CONTAINER...]
```



```bash
# Run a command in a new container
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
	    
	-d, --detach			Detached mode: run command in the background
	-h, --hostname string
	-i, --interactive		Keep STDIN open even if not attached
	    --name string		Assign a name to the container
	-p, --publish list		Publish a container's port(s) to the host
	    --privileged
	-t, --tty				Allocate a pseudo-TTY
	-v, --volume list	

# Run a command in a running container
docker exec [OPTIONS] CONTAINER COMMAND [ARG...]
```



```bash
docker search vsftpd

# redis
docker run --name redis -itd -p 6379:6379 redis
# mysql
docker run --name mysql -itd -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 mysql:8.0.19
# vsftpd
docker run -d -p 20:20 -p 21:21 -p 21100-21110:21100-21110 -v D:\FTP:/FTP -e FTP_USER=user -e FTP_PASS=password -e PASV_MIN_PORT=21100 -e PASV_MAX_PORT=21110 --name vsftpd fauria/vsftpd

docker stop redis mysql

docker start redis mysql

docker exec -it redis bin/bash
docker exec -it redis redis-cli

docker exec -it mysql bin/bash
docker exec -it mysql mysql -uroot -p
```

