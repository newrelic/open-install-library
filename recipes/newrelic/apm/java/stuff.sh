          findServerType () {
            local mainClass=$( echo "$1" | grep -oP '.*\K(?<=mainClass":").*?(?=\")' )
            if [[ "$mainClass" == "org.apache.catalina.startup.Bootstrap" ]]; then
              echo "tomcat"
            else
              echo "other"
            fi
          }

          systemd_restart_service() {
            local SERVICE=$1
            echo "Restarting $SERVICE..." >&2
            if [[ "{{.NEW_RELIC_TEST_MODE}}" == "true" ]]; then
              return 0
            fi
            # TODO replace the config with our backup, reload and mark as failed install
            if [[ -f {{.TMP_DIR}}/systemd_daemon_reload ]]; then
              FAILED=$(systemctl daemon-reload | wc -l)
              if [[ $FAILED -gt 0 ]]; then
                echo -e "daemon reload failure, revert service $SERVICE to original configuration" >&2
              fi
            fi
            systemctl restart ${SERVICE}
            echo "$SERVICE" >> {{.TMP_DIR}}/systemd_restarted_services
          }

          supervisord_restart_service() {
            local service=$1
            if [[ "{{.NEW_RELIC_TEST_MODE}}" == "true" ]]; then
              return 0
            fi
            supervisorctl restart ${service} > /dev/null
            echo "$service" >> {{.TMP_DIR}}/supervisord_restarted_services
          }

          tomcat_save_configuration() {
            local configFolder=$1
            local configFilename=$2
            local user=$3
            local service=$4
            local configFile="$configFolder/$configFilename"
            local appName="{{.HOSTNAME}}"

            if [[ -n "$service" && "$service" != "tomcat" ]]; then
              appName="$service"
            fi

            if [[ "{{.NEW_RELIC_ASSUME_YES}}" != "true" ]]; then
              echo -n "Enter an app name (default: $appName): "
              read -r answer
              if [[ -n $answer ]]; then
                appName=$answer
              fi
            fi

            # we're putting stuff in the setenv.sh we created
            # setup.env is only used if using catalina.sh/daemon.sh to control tomcat
            local configFile="$configFolder/$configFilename"
            if [[ -f $configFile ]]; then
              echo "Modifying $configFile"
              cp $configFile $configFile.newrelic.bkp
            else
              echo "Creating $configFile"
              if [[ ! -d "$configFolder" ]]; then
                mkdir $configFolder
                chown $user $configFolder
                chmod 700 $configFolder
              fi
              touch $configFile
              chown $user $configFile
              chmod 500 $configFile
            fi

            # rewrite CATALINA_OPTS
            sudo sed -i "/New Relic switch automatically/d" $configFile
            sudo sed -i "/CATALINA_OPTS=\"\$CATALINA_OPTS -javaagent:\/opt\/newrelic/d" $configFile
            echo "# ---- New Relic switch automatically added on $(date)" >> $configFile
            echo "CATALINA_OPTS=\"\$CATALINA_OPTS -javaagent:/opt/newrelic/$appName/newrelic.jar\"" >> $configFile

            mkdir -p /opt/newrelic/$appName/logs
            cp {{.TMP_DIR}}/newrelic.jar /opt/newrelic/$appName
            cp {{.TMP_DIR}}/newrelic.yml /opt/newrelic/$appName
            chown -R $user /opt/newrelic/$appName

            local host=""
            if [[ "{{.NEW_RELIC_REGION}}" == "STAGING" ]]; then
              host="\n  host: 'staging-collector.newrelic.com'"
            elif [[ "{{.NEW_RELIC_REGION}}" == "EU" ]]; then
              host="\n  host: 'collector.eu.newrelic.com'"
            fi

            sed -i "s/license_key: '<%= license_key %>'/license_key: '{{.NEW_RELIC_LICENSE_KEY}}'$host/" /opt/newrelic/$appName/newrelic.yml
            sed -i "s/app_name: My Application$/app_name: $appName/" /opt/newrelic/$appName/newrelic.yml

            touch {{.TMP_DIR}}/tomcat_configured
          }

          save_sysd_script_configuration() {
            local SERVICE=$1
            local CATALINA_HOME=$2
            local USER=$(ps -q $pid -h -o user)

            if [[ "{{.NEW_RELIC_ASSUME_YES}}" != "true" ]]; then
              echo -n "Enter an app name (default: $SERVICE): "
              read -r answer
              if [[ -n $answer ]]; then
                SERVICE=$answer
              fi
            fi

            echo "Catalina home: $CATALINA_HOME"
            local CONFIG_FILE="$CATALINA_HOME/bin/setenv.sh"
            if [[ -f $CONFIG_FILE ]]; then
              echo "Modifying $CONFIG_FILE"
              cp $CONFIG_FILE $CONFIG_FILE.newrelic.bkp
            else
              echo "Creating $CONFIG_FILE"
              cd bin/
              touch setenv.sh
            fi

            # rewrite CATALINA_OPTS
            sudo sed -i "/New Relic switch automatically/d" "$CONFIG_FILE"
            sudo sed -i "/CATALINA_OPTS=\"\$CATALINA_OPTS -javaagent:\/opt\/newrelic/d" "$CONFIG_FILE"
            echo "# ---- New Relic switch automatically added on $(date)" >> $CONFIG_FILE
            echo "CATALINA_OPTS=\"\$CATALINA_OPTS -javaagent:/opt/newrelic/$SERVICE/newrelic.jar\"" >> $CONFIG_FILE

            mkdir -p /opt/newrelic/$SERVICE/logs
            cp {{.TMP_DIR}}/newrelic.jar /opt/newrelic/$SERVICE
            cp {{.TMP_DIR}}/newrelic.yml /opt/newrelic/$SERVICE
            chown -R $USER /opt/newrelic/$SERVICE

            local host=""
            if [[ "{{.NEW_RELIC_REGION}}" == "STAGING" ]]; then
              host="\n  host: 'staging-collector.newrelic.com'"
            elif [[ "{{.NEW_RELIC_REGION}}" == "EU" ]]; then
              host="\n  host: 'collector.eu.newrelic.com'"
            fi

            sed -i "s/license_key: '<%= license_key %>'/license_key: '{{.NEW_RELIC_LICENSE_KEY}}'$host/" /opt/newrelic/$SERVICE/newrelic.yml
            sed -i "s/app_name: My Application$/app_name: $SERVICE/" /opt/newrelic/$SERVICE/newrelic.yml

            touch {{.TMP_DIR}}/tomcat_configured
            return 0
          }

          save_sysd_command_line_configuration() {
            local SERVICE=$1
            local SERVICE_CONFIG_FILE=$2
            local START_COMMAND=$3
            local USER=$(ps -q $pid -h -o user)

            # TODO check to make sure newrelic jar isn't present, if so don't add - check for $service/newrelic.jar
            sed -i "s/CATALINA_OPTS/CATALINA_OPTS -javaagent\:\/opt\/newrelic\/${SERVICE}\/newrelic.jar/" $SERVICE_CONFIG_FILE

            if [[ "{{.NEW_RELIC_ASSUME_YES}}" != "true" ]]; then
              echo -n "Enter an app name (default: $SERVICE): "
              read -r answer
              if [[ -n $answer ]]; then
                SERVICE=$answer
              fi
            fi

            mkdir -p /opt/newrelic/$SERVICE/logs
            cp {{.TMP_DIR}}/newrelic.jar /opt/newrelic/$SERVICE
            cp {{.TMP_DIR}}/newrelic.yml /opt/newrelic/$SERVICE
            chown -R $USER /opt/newrelic/$SERVICE

            local host=""
            if [[ "{{.NEW_RELIC_REGION}}" == "STAGING" ]]; then
              host="\n  host: 'staging-collector.newrelic.com'"
            elif [[ "{{.NEW_RELIC_REGION}}" == "EU" ]]; then
              host="\n  host: 'collector.eu.newrelic.com'"
            fi

            sed -i "s/license_key: '<%= license_key %>'/license_key: '{{.NEW_RELIC_LICENSE_KEY}}'$host/"  /opt/newrelic/$SERVICE/newrelic.yml
            sed -i "s/app_name: My Application$/app_name: $SERVICE/" /opt/newrelic/$SERVICE/newrelic.yml
            touch {{.TMP_DIR}}/tomcat_configured
            return 0
          }

          save_systemd_configuration() {
            local SERVICE=$1
            local CATALINA_HOME=$2

            SERVICE_CONFIG_FILE=$(systemctl status $SERVICE | grep -oP '(?<=\().*(?=\; enabled)')
            echo "service config file: $SERVICE_CONFIG_FILE" >&2
            if [[ ! -z $SERVICE_CONFIG_FILE ]]; then
              # save a backup - may be useful if things go south...
              touch {{ .TMP_DIR }}/$SERVICE_sysd_config.bkp
              cat $SERVICE_CONFIG_FILE >> {{ .TMP_DIR}}/$SERVICE_sysd_config.bkp

              echo "Before if command line" >&2
              # 1 - check if command line, add javaagent here
              CMDLINE_START_COMMAND=$(cat $SERVICE_CONFIG_FILE | sed -n '/ExecStart=/{:start /start/!{N;b start};/org.apache.catalina.startup.Bootstrap/p}')
              CATALINA_OPTS_EXIST=$(echo $CMDLINE_START_COMMAND | grep 'CATALINA_OPTS' | wc -l)
              if [ $CATALINA_OPTS_EXIST -gt 0 ]; then
                touch {{ .TMP_DIR }}/systemd_daemon_reload
                echo "saving command line config" >&2
                save_sysd_command_line_configuration $SERVICE $SERVICE_CONFIG_FILE $CMDLINE_START_COMMAND
                return 0
              fi

              echo "Before if shell script" >&2
              # 2 - check if shell script, if catalina/daemon we can use setenv.sh
              # TODO make this sed multiline just in case...
              SHELL_START_COMMAND=$(cat $SERVICE_CONFIG_FILE | sed -n '/ExecStart=.*catalina.sh/p'  | wc -l)
              if [ $SHELL_START_COMMAND -gt 0 ]; then
                echo "saving shell config" >&2
                save_sysd_script_configuration $SERVICE $CATALINA_HOME
                return 0
              fi

              echo "Systemd service configuration found, but could not configure: $service" >&2
              return 1
            else
              echo "Systemd service configuration not found: $service" >&2
              return 1
            fi
          }

          tomcat_configure() {
            local catalinaBase=$1
            local catalinaHome=$2
            local user=$3
            local service=$4
            local isManagedBySupervisor=$5

            echo "\nStarting configuration of Tomcat ($service)."

            if [[ "$isManagedBySupervisor" == "false" ]]; then
              save_systemd_configuration $service $catalinaHome
              systemd_restart_service $service

            else
              if [[ -f $catalinaHome/bin/setenv.sh ]]; then
                tomcat_save_configuration $catalinaBase/bin setenv.sh $user $service || return 1
              else
                local red='\033[0;31m'
                local noColor='\033[0m'
                echo -e "
                  ${red}Unable to find the proper configuration file.
                  Check https://docs.newrelic.com/docs/agents/java-agent/installation/install-java-agent/ for manual configuration options.${noColor}
                "
                return 1
              fi
            fi
          }

          tomcat() {
            local pid=$1
            local workDir=$(readlink /proc/$pid/cwd)
            local catalinaBase=$(cat /proc/$pid/cmdline | xargs -0 | grep -oP "(?<=catalina\.base=)\K[\-\.\w/]+")
            catalinaBase=$(cd $workDir; realpath $catalinaBase)
            local catalinaHome=$(cat /proc/$pid/cmdline | xargs -0 | grep -oP "(?<=catalina\.home=)\K[\-\.\w/]+")
            catalinaHome=$(cd $workDir; realpath $catalinaHome)
            local user=$(ps -q $pid -h -o user)

            # check if systemd is managing supervisord.service that is running tomcat
            local service=""
            local isSupervisord="false"
            service=$(systemctl status $pid | head -n1 | grep -oP "(?<=. )\K.+(?=\.service)")
            if [[ "$service" == "supervisor" || "$service" == "supervisord" ]]; then
              isSupervisord="true"
              service=$(supervisorctl status | grep "pid $pid" | cut -d' ' -f1)
            fi

            local configFailed="false"
            tomcat_configure $catalinaBase $catalinaHome $user $service $isSupervisord || configFailed="true"
            if [[ "$configFailed" == "true" ]]; then
              return 0
            fi

            if [[ "$isSupervisord" == "true" ]]; then
              echo "$catalinaBase/bin/setenv.sh" > {{.TMP_DIR}}/supervisord_$service.configFile
              echo "Configuration finished."
              echo "Restarting Tomcat."
              supervisord_restart_service $service
              echo "Restart completed."
            fi

          }

          ##################
          # main
          ##################
          nri-lsi-java -list | tr -d '[]' | tr ',' '\n' > {{.TMP_DIR}}/processes
          for JAVA_PID in $(cat {{.TMP_DIR}}/processes)
          do
            INTROSPECTION_DATA=$(nri-lsi-java -introspect ${JAVA_PID})
            SERVER_TYPE=$(findServerType $INTROSPECTION_DATA)
            IS_STANDALONE=$(systemctl status $JAVA_PID | head -n1 | grep -oP "(?<=. )\K.+(?=\.scope)" | wc -l)

            if [[ "$SERVER_TYPE" == "tomcat" && $IS_STANDALONE -eq 0 ]]; then
              touch {{.TMP_DIR}}/tomcat_found
              tomcat $JAVA_PID
            fi
          done

          if [[ ! -f {{.TMP_DIR}}/tomcat_found ]]; then
            echo -e "\nNo Tomcat processes found running on the host.\n" >&2
            exit 3
          fi

          if [[ ! -f {{.TMP_DIR}}/tomcat_configured ]]; then
            echo -e "\nUnable to configure any Tomcats running on the host.\n" >&2
            exit 2
          fi