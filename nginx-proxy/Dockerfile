FROM nginx:alpine
RUN mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
COPY nginx.conf /etc/nginx/conf.d/custom.conf
