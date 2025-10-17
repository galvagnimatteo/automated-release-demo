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

    parameters {
        booleanParam(
            name: 'RELEASE_TO_RC',
            defaultValue: false,
            description: 'Check this to prepare a new release (creates pre-release branch and PR)'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    sh 'git fetch --tags --force'

                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.CURRENT_BRANCH = env.GIT_BRANCH.replaceAll('origin/', '')
                }
            }
        }

        stage('Build JAR') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Build DEB Package') {
            steps {
                sh './build-deb.sh'
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'target/*.jar, *.deb', fingerprint: true
            }
        }

        // This uses semantic release to bump version, generate changelog and create tag.
        // Since we are working on branch pre-release, tag will be created there, so we manually remove it before pushing.
        stage('Prepare Release') {
            when {
                allOf {
                    branch 'main'
                    expression { params.RELEASE_TO_RC == true }
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
                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@assext.com"
                    '''

                    env.PRE_RELEASE_BRANCH = "pre-release"

                    sh """
                        git checkout main
                        git pull origin main

                        if git show-ref --verify --quiet refs/heads/${env.PRE_RELEASE_BRANCH}; then
                            git branch -D ${env.PRE_RELEASE_BRANCH}
                        fi

                        git fetch origin
                        if git show-ref --verify --quiet refs/remotes/origin/${env.PRE_RELEASE_BRANCH}; then
                            git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@github.com/${GIT_CREDENTIALS_USR}/automated-release-demo.git --delete ${env.PRE_RELEASE_BRANCH}
                        fi

                        git checkout -b ${env.PRE_RELEASE_BRANCH}
                        git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@github.com/${GIT_CREDENTIALS_USR}/automated-release-demo.git ${env.PRE_RELEASE_BRANCH}
                    """

                    withEnv([
                        "GIT_BRANCH=${env.PRE_RELEASE_BRANCH}",
                        "BRANCH_NAME=${env.PRE_RELEASE_BRANCH}"
                    ]) {
                        sh 'npx semantic-release --no-ci'
                    }

                    env.RELEASE_VERSION = sh(
                        script: 'git describe --tags --abbrev=0',
                        returnStdout: true
                    ).trim()

                    sh """
                        git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@github.com/${GIT_CREDENTIALS_USR}/automated-release-demo.git --delete ${env.RELEASE_VERSION} 2>/dev/null || true
                        git tag -d ${env.RELEASE_VERSION}
                        git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@github.com/${GIT_CREDENTIALS_USR}/automated-release-demo.git ${env.PRE_RELEASE_BRANCH}
                    """

                    def prBody = """🤖 Automated release preparation for ${env.RELEASE_VERSION}"""

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
                }
            }
        }

        // Once pre-release has been merged into main, we create the tag on main
        stage('Tag for release') {
            when {
                allOf {
                    branch 'main'
                    expression {
                        return env.GIT_COMMIT_MSG.contains('chore(release):') &&
                               env.GIT_COMMIT_MSG.contains('[skip ci]')
                    }
                    expression {
                        def version = sh(
                            script: 'echo "${GIT_COMMIT_MSG}" | grep -oP "chore\\\\(release\\\\): \\\\K[0-9]+\\\\.[0-9]+\\\\.[0-9]+" || echo ""',
                            returnStdout: true
                        ).trim()

                        if (!version) {
                            return false
                        }

                        sh 'git fetch --tags --force'

                        def tagExists = sh(
                            script: "git tag -l v${version}",
                            returnStdout: true
                        ).trim()

                        return tagExists == ''
                    }
                }
            }
            steps {
                script {
                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@assext.com"

                        VERSION=$(echo "${GIT_COMMIT_MSG}" | grep -oP "chore\\(release\\): \\K[0-9]+\\.[0-9]+\\.[0-9]+")
                        TAG="v${VERSION}"

                        git tag -a "${TAG}" -m "Release ${VERSION}"
                        git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@github.com/${GIT_CREDENTIALS_USR}/automated-release-demo.git "${TAG}"
                    '''

                    env.TAG_CREATED = 'true'
                }
            }
        }

        // If tag has been created we upload to RC
        stage('Release to RC') {
            when {
                allOf {
                    branch 'main'
                    expression { env.TAG_CREATED == 'true' }
                }
            }
            steps {
                script {
                    def tagName = sh(script: 'git tag --points-at HEAD', returnStdout: true).trim()
                    def version = sh(script: 'mvn help:evaluate -Dexpression=project.version -q -DforceStdout', returnStdout: true).trim()

                    echo """
                    ═══════════════════════════════════════════════════════════
                    🎉 RELEASING TO RC REPOSITORY
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
        always {
            cleanWs()
        }
    }
}