FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

RUN chown -R flutter:flutter /app
USER flutter

COPY --chown=flutter:flutter pubspec.* /app/
RUN flutter pub get

COPY --chown=flutter:flutter . /app/

CMD ["flutter", "run", "-d", "web-server", "--web-hostname", "0.0.0.0", "--web-port", "8080"]