# container to build the application JAR and cache the .m2 repository
FROM maven:3-eclipse-temurin-25-alpine AS builder
WORKDIR /builder
COPY . .
# build the app
RUN --mount=type=cache,target=/root/.m2 mvn package spring-boot:repackage -DskipTests
# extract the dependencies
RUN java -Djarmode=tools -jar target/my-animalz.jar extract --layers --destination extracted
# analyze the dependencies
# add jdk.naming.dns module for Mongo srv discovery [hackintosh]
RUN jdeps --ignore-missing-deps -q \
    --print-module-deps \
    --recursive \
    --multi-release 25 \
    --class-path '/builder/extracted/dependencies/lib/*' \
    ./target/my-animalz.jar > deps.info

# create a custom JRE
RUN jlink \
    --verbose \
    --add-modules $(cat deps.info) \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --output customjre

# container to run the application
FROM alpine:latest
# set the custom Java runtime
ENV JAVA_HOME=/jre
ENV PATH="${JAVA_HOME}/bin:${PATH}"
COPY --from=builder /builder/customjre /jre

# copy the application and its dependencies
WORKDIR /app
COPY --from=builder /builder/extracted/dependencies/ ./
COPY --from=builder /builder/extracted/spring-boot-loader/ ./
COPY --from=builder /builder/extracted/snapshot-dependencies/ ./
COPY --from=builder /builder/extracted/application/ ./

EXPOSE 8080

ENTRYPOINT ["java", "-XX:+UseCompactObjectHeaders", "-jar", "my-animalz.jar"]
