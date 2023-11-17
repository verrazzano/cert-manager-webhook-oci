def agentLabel = env.JOB_NAME.contains('main') ? "2.0-large-phx" : "2.0-large-phx"
def BASE_IMAGE = ""

pipeline {
    options {
        timestamps ()
    }

    agent {
       docker {
            image "${RUNNER_DOCKER_IMAGE}"
            args "${RUNNER_DOCKER_ARGS}"
            registryUrl "${RUNNER_DOCKER_REGISTRY_URL}"
            registryCredentialsId 'ocir-pull-and-push-account'
            label "${agentLabel}"
        }
    }

    parameters {
        string (name: 'DOCKER_REPO',
                defaultValue: 'ghcr.io',
                description: 'Docker image repo.',
                trim: true)
        string (name: 'DOCKER_NAMESPACE',
                defaultValue: 'verrazzano',
                description: 'Docker image namespace.',
                trim: true)
        string (name: 'DOCKER_REPO_CREDS',
                defaultValue: 'github-packages-credentials-rw',
                description: 'Credentials for Docker repo.',
                trim: true)
    }

    environment {
        OCI_CLI_AUTH = "instance_principal"
        OCI_OS_REGION = "us-phoenix-1"
        OCI_OS_NAMESPACE = credentials('oci-os-namespace')
        OCI_OS_BUCKET = "verrazzano-builds"

        DOCKER_REPO_URL = "https://" + "${params.DOCKER_REPO}"
        DOCKER_PUBLISH_IMAGE_NAME = 'cert-manager-webhook-oci'
        DOCKER_CI_IMAGE_NAME = 'cert-manager-webhook-oci-jenkins'
        DOCKER_IMAGE_NAME = "${params.DOCKER_REPO}/${params.DOCKER_NAMESPACE}/${env.BRANCH_NAME ==~ /^release-.*/ || env.BRANCH_NAME == 'main' ? env.DOCKER_PUBLISH_IMAGE_NAME : env.DOCKER_CI_IMAGE_NAME}"
	    DOCKER_IMAGE_TAG = get_image_tag()

        // File containing base image information
        BASE_IMAGE_INFO_FILE = "base-image-v1.0.0.txt"
    }

    stages {
        stage('Build') {
            steps {
                downloadBaseImageInfoFile()
                script {
                    def imageProps = readProperties file: "${WORKSPACE}/${BASE_IMAGE_INFO_FILE}"
                    BASE_IMAGE = imageProps['base-image']
                    env.BASE_IMAGE = "${BASE_IMAGE}"
                    echo "Base Image: ${BASE_IMAGE}"

                }
                withDockerRegistry(credentialsId: params.DOCKER_REPO_CREDS, url: env.DOCKER_REPO_URL) {
                    sh """
                        # Build the docker image and push to registry
                        make docker-build
			            docker push ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                    """
                }
            }
        }

        stage('Scan Image') {
            steps {
                script {
                    scanContainerImage "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: '**/scanning-report*.json', allowEmptyArchive: true
                }
            }
        }
    }
    post {
        cleanup {
            deleteDir()
        }
    }

}

// Derive the docker image tag
def get_image_tag() {
    def props = readProperties file: '.verrazzano-development-version'
    VERRAZZANO_DEV_VERSION = props['verrazzano-development-version']
    time_stamp = sh(returnStdout: true, script: "date +%Y%m%d%H%M%S").trim()
    short_commit_sha = sh(returnStdout: true, script: "git rev-parse --short HEAD").trim()
    docker_image_tag = "v${VERRAZZANO_DEV_VERSION}-${time_stamp}-${short_commit_sha}"
    println("image tag: " + docker_image_tag)
    return docker_image_tag
}


// Download the file containing the base image name and digest
def downloadBaseImageInfoFile() {
    sh """
        oci --region ${OCI_OS_REGION} os object get --namespace ${OCI_OS_NAMESPACE} -bn ${OCI_OS_BUCKET} --name verrazzano-base-images/${BASE_IMAGE_INFO_FILE} --file ${WORKSPACE}/${BASE_IMAGE_INFO_FILE}
    """
}
