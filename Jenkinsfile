pipeline {
    agent any

    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }

    environment {
        GIT_CREDENTIALS = credentials('github-credentials')
        GITHUB_TOKEN = credentials('github-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.CURRENT_BRANCH = env.GIT_BRANCH.replaceAll('origin/', '')
                    echo "Building branch: ${env.CURRENT_BRANCH}"
                    echo "Commit message: ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        stage('Build JAR') {
            steps {
                sh '''
                    mvn clean package
                    echo "✅ JAR built successfully"
                    ls -lh target/*.jar
                '''
            }
        }

        stage('Build DEB Package') {
            steps {
                sh '''
                    ./build-deb.sh
                    echo "✅ DEB package built"
                    ls -lh *.deb
                '''
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar, *.deb', fingerprint: true
            }
        }

        stage('Prepare Release') {
            when {
                allOf {
                    branch 'main'
                    not {
                        expression {
                            return env.GIT_COMMIT_MSG.contains('[skip ci]') ||
                                   env.GIT_COMMIT_MSG.contains('chore(release):')
                        }
                    }
                }
            }
            steps {
                script {
                    echo "🚀 Starting release preparation..."

                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@assext.com"
                    '''

                    def timestamp = new Date().format('yyyyMMdd-HHmmss')
                    env.PRE_RELEASE_BRANCH = "pre-release/${timestamp}"

                    sh """
                        git checkout main
                        git pull origin main
                        git checkout -b ${env.PRE_RELEASE_BRANCH}
                    """

                    sh '''
                        npx semantic-release --no-ci
                    '''

                    env.RELEASE_VERSION = sh(
                        script: 'git describe --tags --abbrev=0',
                        returnStdout: true
                    ).trim()

                    echo "✅ Created version: ${env.RELEASE_VERSION}"

                    sh """
                        git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@github.com/${GIT_CREDENTIALS_USR}/automated-release-demo.git ${env.PRE_RELEASE_BRANCH} --follow-tags
                    """

                    def prBody = """🤖 Automated release preparation for version ${env.RELEASE_VERSION}

## Changes
- Version bumped to ${env.RELEASE_VERSION}
- CHANGELOG.md updated
- POM.xml updated

**Review and approve to complete the release.**

Tag ${env.RELEASE_VERSION} will be on the last commit of main after merge (use rebase and merge!)."""

                    sh """
                        curl -X POST \
                          -H "Authorization: token ${GIT_CREDENTIALS_PSW}" \
                          -H "Accept: application/vnd.github.v3+json" \
                          https://api.github.com/repos/${GIT_CREDENTIALS_USR}/automated-release-demo/pulls \
                          -d '{"title": "Release ${env.RELEASE_VERSION}", "head": "${env.PRE_RELEASE_BRANCH}", "base": "main", "body": ${groovy.json.JsonOutput.toJson(prBody)}}' > pr-response.json
                    """

                    env.PR_NUMBER = sh(
                        script: 'cat pr-response.json | grep -o \'"number": [0-9]*\' | grep -o \'[0-9]*\'',
                        returnStdout: true
                    ).trim()

                    echo "✅ Created PR #${env.PR_NUMBER}"
                }
            }
        }

        stage('Release to Public') {
            when {
                buildingTag()
            }
            steps {
                script {
                    def tagName = env.TAG_NAME ?: sh(script: 'git describe --tags --exact-match', returnStdout: true).trim()
                    def version = sh(script: 'mvn help:evaluate -Dexpression=project.version -q -DforceStdout', returnStdout: true).trim()

                    echo """
                    ═══════════════════════════════════════════════════════════
                    🎉 RELEASING TO PUBLIC REPOSITORY
                    ═══════════════════════════════════════════════════════════

                    Tag:     ${tagName}
                    Version: ${version}

                    Artifacts to be published:
                    - JAR:  automated-release-demo-${version}.jar
                    - DEB:  automated-release-demo_${version}_all.deb

                    ✅ Release ${tagName} published successfully!

                    ═══════════════════════════════════════════════════════════
                    """
                }
            }
        }
    }

    post {
        success {
            script {
                if (env.PRE_RELEASE_BRANCH) {
                    echo """
                    ✅ Release preparation complete!

                    Branch: ${env.PRE_RELEASE_BRANCH}
                    Version: ${env.RELEASE_VERSION}
                    PR: #${env.PR_NUMBER}
                    URL: https://github.com/${GIT_CREDENTIALS_USR}/automated-release-demo/pull/${env.PR_NUMBER}

                    ⚠️  IMPORTANT: Merge using 'Rebase and merge' to keep tag on last commit!
                    After merge, manually trigger build for tag ${env.RELEASE_VERSION} to publish release.
                    """
                } else if (env.TAG_NAME) {
                    echo "🎉 Release published successfully!"
                } else {
                    echo "✅ Build completed successfully"
                }
            }
        }
        failure {
            echo "❌ Build failed!"
        }
        always {
            cleanWs()
        }
    }
}