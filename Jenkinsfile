pipeline {

  agent none

  options {
    buildDiscarder(
      logRotator(
        artifactDaysToKeepStr: '28',
        daysToKeepStr: '28',
        numToKeepStr: '5',
        artifactNumToKeepStr: '5'
      )
    )
  }

  triggers {
    pollSCM('H/30 * * * *')
  }

  stages {

        stage('Ubuntu32 (Vortex)') {
          agent {
            node {
              label 'CentOS9_x86_64'
            }
          }

          stages {

//            stage('Compile and test') {
//              steps {
//                sh './jenkins.sh test'
//              }
//            }

            stage('Build Debian packages') {
              steps {
                sh '/opt/nidas/bin/start_podman bionic "/root/current/scripts/build_all.sh /root/current"'
//                This is for non-container build, on a VM.
//                sh 'scripts/build_all.sh
              }
            }
          }
        }
  }

  post {
    changed
    {
      emailext from: "granger@ucar.edu",
        to: "cjw@ucar.edu",
//        to: "granger@ucar.edu, cjw@ucar.edu, cdewerd@ucar.edu",
        recipientProviders: [developers(), requestor()],
        subject: "Jenkins build ${env.JOB_NAME}: ${currentBuild.currentResult}",
        body: "Job ${env.JOB_NAME}: ${currentBuild.currentResult}\n${env.BUILD_URL}"
    }
  }

}
