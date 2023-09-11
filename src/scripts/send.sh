if [ ! -f "<<parameters.file>>" ]; then
            echo "File not found!"
            exit 0
        fi
        LOG_FILE=$(realpath "<<parameters.file>>")
        LOG_BULKS=$(mktemp -d)
        pushd $LOG_BULKS
          split -C 2M -d "$LOG_FILE" ''
        popd
        for bulk in $LOG_BULKS/*; do
          jq -nMc \
            --rawfile lines "$bulk" \
            --arg private_key "${<<parameters.private_key>>}" \
            --arg application "<<parameters.application>>" \
            --arg subsystem "<<parameters.subsystem>>" \
            --arg hostname "<<parameters.hostname>>" \
            --arg category "<<parameters.category>>" \
            --arg class "<<parameters.class>>" \
            --arg method "<<parameters.method>>" \
            --arg thread "<<parameters.thread>>" '{
            "privateKey": $private_key,
            "applicationName": $application,
            "subsystemName": $subsystem,
            "computerName": $hostname,
            "logEntries": [
              $lines | split("<<parameters.newline_pattern>>"; "") | to_entries | .[] | {
                "timestamp": (now * 1000 + .key),
                "severity": 3,
                "text": .value | select(.!=""),
                "category": $category,
                "className": $class,
                "methodName": $method,
                "threadId": $thread
              }
            ]
          }' | curl -X POST -H 'Content-Type: application/json' -d @- -s 'https://<<parameters.endpoint>>/api/v1/logs'
        done
        rm -rf "$LOG_BULKS"