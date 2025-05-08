pipeline {
    agent any

    environment {
        IMAGE_TAG = 'latest'
        TFVARS_FILE = 'terraform.tfvars'
    }

    parameters {
        choice(
            name: 'apply_or_destroy',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to apply or destroy Terraform resources.'
        )
    }

    stages {

        stage('Git Clone') {
            steps {
                git branch: 'main',
                    credentialsId: 'git',
                    url: 'https://github.com/sahar449/full-pro.git'
            }
        }

        stage('Extract Variables from tfvars') {
            steps {
                script {
                    env.AWS_REGION = sh(script: "sed -n 's/^region *= *\"\\(.*\\)\"/\\1/p' ${TFVARS_FILE}", returnStdout: true).trim()
                    env.CLUSTER_NAME = sh(script: "sed -n 's/^cluster_name *= *\"\\(.*\\)\"/\\1/p' ${TFVARS_FILE}", returnStdout: true).trim()
                    echo "AWS Region is: ${env.AWS_REGION}"
                    echo "EKS Cluster name is: ${env.CLUSTER_NAME}"
                }
            }
        }

        stage('Snyk SAST Scan') {
            steps {
                sh "snyk iac test --scan=terraform"
            }
        }


        stage('Create ECR Repository') {
            steps {
                sh '''
                aws ecr describe-repositories --repository-names my-app --region $AWS_REGION || \
                aws ecr create-repository \
                    --repository-name my-app \
                    --region $AWS_REGION \
                    --image-scanning-configuration scanOnPush=true \
                    --encryption-configuration encryptionType=AES256
                '''
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                withCredentials([string(credentialsId: 'ecr-repo-uri', variable: 'ECR_REPO')]) {
                    sh """
                    docker build -t my-app:\$IMAGE_TAG .
                    docker tag my-app:\$IMAGE_TAG \$ECR_REPO:\$IMAGE_TAG

                    aws ecr get-login-password --region \$AWS_REGION \\
                    | docker login --username AWS --password-stdin \$ECR_REPO

                    docker push \$ECR_REPO:\$IMAGE_TAG
                    """
                }
            }
        }


        stage('Terraform Apply or Destroy') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh "terraform ${params.apply_or_destroy} -auto-approve"
                }
            }
        }

        stage('Helm Upgrade Install') {
            steps {
                withCredentials([
                    string(credentialsId: 'ecr-repo-uri', variable: 'ECR_REPO'),
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                ]) {
                    sh """
                        aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME
                        helm upgrade --install flask ./flask-app \
                            --set image.repository=$ECR_REPO \
                            --set image.tag=$IMAGE_TAG
                    """
                }
            }
        }

    }

    post {
        always {

        success {
            sh 'curl https://www.saharbittman.com'
        }
        failure {
            echo 'Pipeline failed. Running terraform destroy...'
            {
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}
