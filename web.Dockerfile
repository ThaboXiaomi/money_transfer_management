FROM cirrusci/flutter:stable as build

# Enable Flutter tools
WORKDIR /src

# Copy Flutter project
COPY . /src

# Pre-download packages
RUN flutter channel stable && flutter --version && flutter pub get

# Build web release
RUN flutter build web --release

FROM nginx:alpine
COPY --from=build /src/build/web /usr/share/nginx/html

# Replace default nginx.conf to enable single-page app routing (fallback to index.html)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
