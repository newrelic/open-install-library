while true; do
  POLICY_RESULT=$(curl {{ newrelic_api_url_to_use }}/graphql \
    -H 'Content-Type: application/json' \
    -H 'API-Key: {{ newrelic_personal_api_key }}' \
    --data-binary '{"query":"{\n  actor {\n    account(id: {{ newrelic_account_id }}) {\n      alerts {\n        policiesSearch(searchCriteria: {name: \"Golden Signals\"}) {\n          policies {\n            name\n \n            id\n          }\n          totalCount\n        }\n      }\n    }\n  }\n}\n", "variables":""}'
  )
{% raw %}
  POLICY_ID=$(echo $POLICY_RESULT | /usr/local/bin/newrelic utils jq '.data.actor.account.alerts.policiesSearch.policies[0] | select(.name=="Golden Signals") | .id | tonumber')
{% endraw %}
  if [ -n "$POLICY_ID" ] && [ $POLICY_ID -gt 0 ] ; then
    curl -sX DELETE {{ newrelic_api_url_to_use }}'/v2/alerts_policies/'$POLICY_ID'.json' -H 'Api-Key:{{newrelic_personal_api_key}}' -i > /dev/null
    continue
  else
    break
  fi
done

