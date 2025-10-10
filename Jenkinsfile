pipeline {
    agent any

    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }

    environment {
        APP_NAME = 'automated-release-demo'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Get Version from POM') {
            steps {
                script {
                    env.APP_VERSION = sh(
                        script: "mvn help:evaluate -Dexpression=project.version -q -DforceStdout",
                        returnStdout: true
                    ).trim()
                    echo "Building version: ${env.APP_VERSION}"
                }
            }
        }

        stage('Create DEB Package') {
            steps {
                script {
                    sh """
                        mkdir -p build/deb/${APP_NAME}_${APP_VERSION}/DEBIAN
                        mkdir -p build/deb/${APP_NAME}_${APP_VERSION}/usr/share/${APP_NAME}

                        cp target/${APP_NAME}-${APP_VERSION}.jar build/deb/${APP_NAME}_${APP_VERSION}/usr/share/${APP_NAME}/

                        cat > build/deb/${APP_NAME}_${APP_VERSION}/DEBIAN/control << EOF
Package: ${APP_NAME}
Version: ${APP_VERSION}
Section: utils
Priority: optional
Architecture: all
Maintainer: Matteo Galvagni <matteo@example.com>
Description: Automated Release Demo
 Demo project for testing automated releases with Jenkins
EOF

                        dpkg-deb --build build/deb/${APP_NAME}_${APP_VERSION}

                        mv build/deb/${APP_NAME}_${APP_VERSION}.deb target/

                        echo "DEB package created: ${APP_NAME}_${APP_VERSION}.deb"
                    """
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar,target/*.deb', fingerprint: true
            }
        }
    }

    post {
        success {
            echo "✅ Build successful!"
            echo "JAR: ${APP_NAME}-${APP_VERSION}.jar"
            echo "DEB: ${APP_NAME}_${APP_VERSION}.deb"
        }
        failure {
            echo '❌ Build failed!'
        }
        always {
            cleanWs()
        }
    }
}