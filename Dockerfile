# 1) 빌드 단계: Gradle로 실행 가능한 jar 생성
FROM amazoncorretto:17 AS build
WORKDIR /app
COPY . .
RUN chmod +x ./gradlew && ./gradlew clean bootJar --no-daemon

# 2) 실행 단계: jar만 복사해 실행 (Corretto는 JRE 전용 이미지가 없어 동일 이미지 사용)
FROM amazoncorretto:17
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
