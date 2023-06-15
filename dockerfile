FROM nginx@sha256:e2b24589b948fa93fef694193960ff347a4383d45a50be563d5fa9a68f38643c
WORKDIR /
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]