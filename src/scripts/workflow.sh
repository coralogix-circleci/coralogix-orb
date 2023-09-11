#!/bin/bash
if [ -z "${<<parameters.circle_token>>}" ]; then
            echo "CircleCI API token is not set!"
            exit 0
        fi
        WORKFLOW=$(curl -s -H "circle_token: ${<<parameters.circle_token>>}" "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID")
        WORKFLOW_JOBS=$(curl -s -H "circle_token: ${<<parameters.circle_token>>}" "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/job" | jq '.items | map(select(.name|test("^coralogix/(stats|logs)")|not))')
        WORKFLOW_LENGTH=$(echo "$WORKFLOW_JOBS" | jq 'length')
        PROJECT_SLUG=$(echo "$WORKFLOW" | jq -r '.project_slug')
        mkdir -p /tmp/coralogix
        rm -f /tmp/coralogix/workflow-*.log
        for (( i=0; i<$WORKFLOW_LENGTH; )); do
            WORKFLOW_JOBS=$(curl -s -H "circle_token: ${<<parameters.circle_token>>}" "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/job" | jq '.items | map(select(.name|test("^coralogix/(stats|logs)")|not))')
            JOB_NUMBER=$(echo "$WORKFLOW_JOBS" | jq -r ".[$i].job_number")
            JOB_NAME=$(echo "$WORKFLOW_JOBS" | jq -r ".[$i].name")
            JOB_STATUS=$(echo "$WORKFLOW_JOBS" | jq -r ".[$i].status")
            echo "Checking $((i+1))/$WORKFLOW_LENGTH job $JOB_NAME($JOB_NUMBER) - $JOB_STATUS..."
            if [ "$JOB_STATUS" == "success" ] || [ "$JOB_STATUS" == "failed" ]; then
                if [ "$JOB_NUMBER" != "null" ]; then
                    echo "Collecting data for job $JOB_NAME..."
                    JOB=$(curl -s -H "circle_token: ${<<parameters.circle_token>>}" "https://circleci.com/api/v1.1/project/$PROJECT_SLUG/$JOB_NUMBER")
                    JOB_LOGS=$(echo "$JOB" | jq '.steps[].actions[].output_url | select(.!=null)')
                    if [ -z "$JOB_LOGS" ]; then
                        sleep 10
                        continue
                    fi
                    echo "$JOB" | jq -c 'del(.steps, .circle_yml)' >> /tmp/coralogix/workflow-stats.log
                    echo "$JOB_LOGS" | xargs -n1 curl -s --output - --compressed | jq -r '.[].message' >> /tmp/coralogix/workflow-logs.log
                    echo "Job $JOB_NAME is successfully added to report..."
                else
                    echo "Job $JOB_NAME is approval. Skipping..."
                fi
            elif [ "$JOB_STATUS" == "blocked" ] || [ "$JOB_STATUS" == "on_hold" ] || [ "$JOB_STATUS" == "canceled" ]; then
                echo "Job $JOB_NAME is $JOB_STATUS. Skipping..."
            else
                echo "Job $JOB_NAME is $JOB_STATUS..."
                sleep 10
                continue
            fi
            i="$((i+1))"
        done