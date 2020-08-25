#!/bin/bash
#
# ./certs-extraction.sh > /var/log/certs-extraction.log 2>&1 &
#

# Source .env file
. /mnt/data/.env > /dev/null 2>&1
# Variables
START_LOG=1
START_INIT=1
ACME_JSON=/mnt/data/acme.json
CERTS=/mnt/data/certs
ACME=/mnt/data/acme
ACME_JSON_MD5=$(md5sum $ACME_JSON | awk '{print $1}')
DOMAINS=$DOMAIN
CERTS_HOME=$CERTS
ACME_HOME=$ACME
# Run jq command via docker
jq="docker run -i local/jq"
jq="jq"


echo ""
echo "[ CERTS ] Command: $0 $@"

while true
do
  sleep 3
  if [ -f $ACME_JSON ]; then
    MD5=$(md5sum $ACME_JSON | awk '{print $1}')

    if [ $START_INIT -eq 1 ] || [ $ACME_JSON_MD5 != $MD5 ]; then

      # Set pipe as the delimiter
      IFS='|'
      #Read the split words into an array based on space delimiter
      read -a DOMAIN_ARR <<< "$DOMAINS"
      # Print each value of the array by using the loop
      for DOMAIN in "${DOMAIN_ARR[@]}"; do
        
        if [ ${#DOMAIN_ARR[@]} -gt 1 ]; then
          CERTS=$CERTS_HOME/$DOMAIN
          ACME=$ACME_HOME/$DOMAIN
        fi

        echo "[ CERTS ] Configuration file changed. Generate certificates for $DOMAIN..."
        echo "[ CERTS ] Start time: $(date)"
        runstart=$(date +%s)
        START_LOG=1
        START_INIT=0
        ACME_JSON_MD5=$MD5

        echo "[ CERTS ] Extracting and saving Key"
        cat $ACME_JSON | $jq -r ".[].Certificates[] | select(.domain.main==\"$DOMAIN\") | .key" | base64 -d > $CERTS/ssl-cert.key
        echo "[ CERTS ] Extracting and saving Certificate"
        cat $ACME_JSON | $jq -r ".[].Certificates[] | select(.domain.main==\"$DOMAIN\") | .certificate" | base64 -d > $CERTS/ssl-cert.crt

        echo "[ CERTS ] Convert a DER file (.crt .cer .der) to PEM"
        openssl x509 -in $CERTS/ssl-cert.crt -outform pem -out $CERTS/ssl-cert.pem

        echo "[ CERTS ] Exporting Key and Certificate into PFX"
        openssl pkcs12 -inkey $CERTS/ssl-cert.key -in $CERTS/ssl-cert.crt -password pass: -export -out $CERTS/ssl-cert.pfx

        echo "[ CERTS ] Exporting Key and Certificate like neilpang/acme.sh"
        mkdir -p $ACME
        openssl pkcs12 -in $CERTS/ssl-cert.pfx -nocerts -nodes -password pass: | sed -ne '/-BEGIN PRIVATE KEY-/,/-END PRIVATE KEY-/p' > $ACME/$DOMAIN.key
        openssl pkcs12 -in $CERTS/ssl-cert.pfx -clcerts -nokeys -password pass: | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $ACME/$DOMAIN.cer
        openssl pkcs12 -in $CERTS/ssl-cert.pfx -cacerts -nokeys -chain -password pass: | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $ACME/ca.cer
        cat $ACME/$DOMAIN.cer > $ACME/fullchain.cer && echo "" >> $ACME/fullchain.cer && cat $ACME/ca.cer >> $ACME/fullchain.cer

        if [ -n "$ACME_COPY" ]; then
          # Set pipe as the delimiter
          IFS='|'
          #Read the split words into an array based on space delimiter
          read -a COPY_ARR <<< "$ACME_COPY"
          # Print each value of the array by using the loop
          for P in "${COPY_ARR[@]}"; do
            echo "[ CERTS ] Copy Key and Certificate to $P"
            mkdir -p $P
            cp -rf $ACME/* $P
          done
        fi

        #echo "[ CERTS ] Restart services using new certificates"
        #docker restart onlyoffice owncloud emby

        echo "[ CERTS ] End time: $(date)"
        runend=$(date +%s)
        runtime=$((runend-runstart))
        echo "[ CERTS ] Elapsed time: $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"

      done
    fi
  else
    if [ $START_LOG -eq 1 ]; then
      START_LOG=0
      echo "[ CERTS ] File not found $ACME_JSON"
    fi
  fi
done

exit 0
