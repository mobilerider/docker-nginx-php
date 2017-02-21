# Dockerfile for php7.1, php7.1-fpm and nginx

### Installation.

1- Build image.
```
docker build -t my_image .
```
- 1.1 - Build image passing multiple arguments. (Optional)
```
docker build -t my_image --build-arg environment=production --build-arg nginx_site=my_config/my_site.conf .
```
2- Run container binding 80 port to host.
```
docker run -p 80:80 my_image
```

### Posible arguments
- environment
- nginx_conf
- nginx_site
- supervisord_conf
