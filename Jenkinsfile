pipeline {
    // 파이프라인 전역 에이전트를 두지 않음.
    // 각 stage에서 필요한 도구(JDK, aws-cli)를 담은 컨테이너를 개별로 띄워
    // 컨테이너 안에서 또 컨테이너를 띄우는 중첩을 방지한다.
    agent none

    environment {
        // AWS CLI가 사용할 기본 리전
        AWS_DEFAULT_REGION = 'ap-northeast-2'
        // ECR 레지스트리 주소: <계정ID>.dkr.ecr.<리전>.amazonaws.com
        ECR_REGISTRY = '010526243782.dkr.ecr.ap-northeast-2.amazonaws.com'
        // ECR 리포지토리 이름 (미리 create-repository로 생성돼 있어야 함)
        ECR_REPO     = 'ecsdeploy'
        // 배포 대상 ECS 클러스터 / 서비스 이름 (콘솔에서 만든 실제 이름과 일치해야 함)
        ECS_CLUSTER  = 'ecsdeploy-cluster'
        ECS_SERVICE  = 'ecsdeploy-service'
        // 빌드마다 고유한 이미지 태그. 젠킨스 빌드 번호를 사용해 버전 추적 가능
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
    }

    stages {

        // 1) 소스 컴파일 + 테스트로 실행 가능한 jar 생성
        stage('Build') {
            agent {
                docker {
                    image 'amazoncorretto:17'       // 자바 17 빌드 환경 (Amazon Corretto)
                    reuseNode true                  // 앞 단계와 같은 워크스페이스/노드 재사용
                }
            }
            steps {
                sh '''
                    echo '빌드 시작..'
                    java -version
                    chmod +x ./gradlew          # 젠킨스 체크아웃 후 실행권한 보장
                    ./gradlew clean build       # 컴파일 + 테스트 + bootJar 생성
                '''
            }
        }

        // 2) 도커 이미지를 빌드해 ECR에 push
        //    ※ 이 단계는 Jenkins 노드에서 직접 실행되므로
        //      노드에 docker 데몬 접근 권한 + aws CLI가 설치돼 있어야 한다.
        stage('Docker Build & Push to ECR') {
            agent any
            steps {
                // Jenkins에 등록한 'my-aws' 크리덴셜(Access Key/Secret)을 환경변수로 주입
                withCredentials([usernamePassword(credentialsId: 'my-aws', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''
                        # ECR 로그인 토큰을 받아 docker에 로그인 (토큰은 12시간 유효)
                        aws ecr get-login-password --region $AWS_DEFAULT_REGION \
                          | docker login --username AWS --password-stdin $ECR_REGISTRY

                        # 이미지 빌드 (현재 디렉토리의 Dockerfile 사용)
                        docker build -t $ECR_REPO:$IMAGE_TAG .

                        # ECR 주소로 태그 부여: 버전 태그 + latest 두 개
                        docker tag $ECR_REPO:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG
                        docker tag $ECR_REPO:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPO:latest

                        # ECR로 push (버전 추적용 태그 + 최신용 latest)
                        docker push $ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG
                        docker push $ECR_REGISTRY/$ECR_REPO:latest
                    '''
                }
            }
        }

        // 3) 이번 빌드 이미지 태그를 task-definition에 주입 → 새 리비전 등록 → 그 리비전으로 배포
        //    ※ 이 단계는 Jenkins 노드에서 실행되므로 노드에 aws CLI + jq가 설치돼 있어야 함
        stage('Deploy to ECS') {
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: 'my-aws', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh '''
                        # 이번 빌드로 push한 이미지 주소 (버전 추적용 빌드번호 태그)
                        IMAGE="$ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG"

                        # jq로 task-definition의 image 필드를 이번 빌드 태그로 교체
                        jq --arg IMAGE "$IMAGE" \
                          '.containerDefinitions[0].image = $IMAGE' \
                          aws/task-definition.json > task-def-rendered.json

                        # 교체된 정의로 새 리비전 등록하고, 등록된 리비전 ARN을 캡처
                        TASK_DEF_ARN=$(aws ecs register-task-definition \
                          --cli-input-json file://task-def-rendered.json \
                          --query 'taskDefinition.taskDefinitionArn' --output text)
                        echo "등록된 task definition: $TASK_DEF_ARN"

                        # 정확히 그 리비전으로 서비스 롤링 배포 (버전 고정 → 롤백 용이)
                        aws ecs update-service \
                          --cluster $ECS_CLUSTER \
                          --service $ECS_SERVICE \
                          --task-definition "$TASK_DEF_ARN" \
                          --force-new-deployment

                        # 새 배포가 안정 상태(원하는 태스크 수 실행 + 롤링 완료)가 될 때까지 대기
                        # 새 태스크가 기동에 실패하면 여기서 non-zero로 빠져 젠킨스 잡이 실패 처리됨
                        # (기본 타임아웃: 15초 간격 × 40회 = 최대 약 10분)
                        aws ecs wait services-stable \
                          --cluster $ECS_CLUSTER \
                          --services $ECS_SERVICE
                    '''
                }
            }
        }
    }
}
