#!/bin/bash
jq -nMc \
  --arg name "<<parameters.tag>>" \
  --arg applications "<<parameters.applications>>" \
  --arg subsystems "<<parameters.subsystems>>" \
  --arg icon "<<parameters.icon>>" '{
  "timestamp": (now * 1000),
  "name": $name,
  "application": $applications | split(","),
  "subsystem": $subsystems | split(",")
} | if $icon != "" then .iconUrl |= $icon else . end' | curl -X POST -H "Authorization: Bearer ${<<parameters.api_key>>}" -H "Content-Type: application/json" -d @- -sSL 'https://<<parameters.endpoint>>/api/v1/external/tags'