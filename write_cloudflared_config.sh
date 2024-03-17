TUNNEL_ID="`cat $DATA_DIR/cloudflared/credentials.json | jq '.TunnelID'`"
sed "s/TUNNEL_ID/$TUNNEL_ID/g;s/DOMAIN_NAME/$DOMAIN_NAME/g;s/API_SUBDOMAIN/$API_SUBDOMAIN/g;s/APP_SUBDOMAIN/$APP_SUBDOMAIN/g" \
  ./conf/cloudflared/config.tpl.yaml \
  > ./conf/cloudflared/config.yaml