FROM maven:3.8.7-eclipse-temurin-19-alpine as builder

WORKDIR /app
COPY pom.xml .
COPY src src
RUN mvn package

# Create a custom Java runtime
RUN $JAVA_HOME/bin/jlink \
         --add-modules \
          java.base,java.compiler,java.desktop,java.management,java.naming,java.rmi,java.scripting,java.sql,java.logging,jdk.unsupported \
#         --strip-debug \
         --strip-java-debug-attributes \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /javaruntime


FROM alpine:3.17

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH "${JAVA_HOME}/bin:${PATH}"

RUN apk add tini
ENTRYPOINT[ "/bin/tini" ]

COPY --from=builder /javaruntime $JAVA_HOME

CMD [ \
     "java"\
#    ,"--add-opens=java.base/jdk.internal.misc=ALL-UNNAMED"\
    ,"-jar", "/opt/app/client.jar"\
#    ,"-Dio.netty.tryReflectionSetAccessible=true"\
    ]

COPY --from=builder /app/target/lib /opt/app/lib
COPY --from=builder /app/target/client*.jar /opt/app/client.jar
