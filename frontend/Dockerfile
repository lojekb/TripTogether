FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

COPY pubspec.* /app/
RUN flutter pub get

COPY . /app/

CMD ["flutter", "run", "-d", "web-server", "--web-hostname", "0.0.0.0", "--web-port", "8080"]