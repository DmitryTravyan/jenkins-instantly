node('test') {
    stage('checkout') {
        checkout([
                $class                           : 'GitSCM',
                branches                         : [[name: '*/master']],
                doGenerateSubmoduleConfigurations: false,
                extensions                       : [[$class: 'CleanCheckout']],
                submoduleCfg                     : [],
                userRemoteConfigs                : [[
                                                            credentialsId: 'dsl-user-password',
                                                            url          : 'https://github.com/DmitryTravyan/job-dsl.git',
                                                    ]]
        ])


    }
}
