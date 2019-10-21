#!/usr/bin/env sh
#
#Author: Wolfgang Ebner
#Author: Sven Neubuaer
#Report Bugs here: https://github.com/dampfklon/acme.sh
#
# Usage:
# export ACMEDNS_BASE_URL="https://auth.acme-dns.io"
#
# You can optionally define an already existing account:
#
# export ACMEDNS_USERNAME="<username>"
# export ACMEDNS_PASSWORD="<password>"
# export ACMEDNS_SUBDOMAIN="<subdomain>"
#
########  Public functions #####################

#Usage: dns_acmedns_add   _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
# Used to add txt record
dns_acmedns_add() {
  fulldomain=$1
  txtvalue=$2
  _info "Using acme-dns"
  _debug "fulldomain $fulldomain"
  _debug "txtvalue $txtvalue"

  ACMEDNS_BASE_URL="${ACMEDNS_BASE_URL:-$(_readaccountconf_mutable ACMEDNS_BASE_URL)}"
  ACMEDNS_DOMAINS="${ACMEDNS_DOMAINS:-$(_readdomainconf ACMEDNS_DOMAINS)}"
  ACMEDNS_USERNAME="${ACMEDNS_USERNAME:-$(_readdomainconf ACMEDNS_USERNAME)}"
  ACMEDNS_PASSWORD="${ACMEDNS_PASSWORD:-$(_readdomainconf ACMEDNS_PASSWORD)}"
  ACMEDNS_SUBDOMAIN="${ACMEDNS_SUBDOMAIN:-$(_readdomainconf ACMEDNS_SUBDOMAIN)}"

  ENV_ACMEDNS_BASE_URL="$ACMEDNS_BASE_URL"
  ENV_ACMEDNS_DOMAINS="$ACMEDNS_DOMAINS"
  ENV_ACMEDNS_USERNAME="$ACMEDNS_USERNAME"
  ENV_ACMEDNS_PASSWORD="$ACMEDNS_PASSWORD"
  ENV_ACMEDNS_SUBDOMAIN="$ACMEDNS_SUBDOMAIN"

  if [ "$ACMEDNS_BASE_URL" = "" ]; then
    ACMEDNS_BASE_URL="https://ocletsencrypt.ongov.net"
  fi

  ACMEDNS_UPDATE_URL="$ACMEDNS_BASE_URL/update"
  ACMEDNS_REGISTER_URL="$ACMEDNS_BASE_URL/register"

  if [ ! -z "$ACMEDNS_DOMAINS" ]; then
    _info "Using acme-dns (multi domain mode)"
    # ensure trailing comma is present
    ACMEDNS_DOMAINS="$ACMEDNS_DOMAINS,"
    _debug "ACMEDNS_DOMAINS: $ACMEDNS_DOMAINS"
    while true; do
      # get next domain name
      DOMAIN=$(cut -d ',' -f 1 <<< "$ACMEDNS_DOMAINS")
      _debug "domain $DOMAIN"

      # check if we reached the last entry
      if [ -z "$DOMAIN" ]; then
        _err "no matching acme-dns domain found"
        return 1
      fi

      # check if domain name matches our current domain
      if [[ "$fulldomain" = "_acme-challenge.$DOMAIN" ]]; then
        _debug "fulldomain $fulldomain"
        # if so, extract the correct username, password and subdomain
        USERNAME=$(cut -d ',' -f 1 <<< "$ACMEDNS_USERNAME")
        _debug "USERNAME $USERNAME"
        PASSWORD=$(cut -d ',' -f 1 <<< "$ACMEDNS_PASSWORD")
        _debug "PASSWORD $PASSWORD"
        SUBDOMAIN=$(cut -d ',' -f 1 <<< "$ACMEDNS_SUBDOMAIN")
        _debug "SUBDOMAIN $SUBDOMAIN"
        break
      fi
      # take next record
      ACMEDNS_DOMAINS=$(cut -d ',' -f 2- <<< "$ACMEDNS_DOMAINS")
      _debug "ACMEDNS_DOMAINS $ACMEDNS_DOMAINS"
      ACMEDNS_USERNAME=$(cut -d ',' -f 2- <<< "$ACMEDNS_USERNAME")
      _debug "ACMEDNS_USERNAME $ACMEDNS_USERNAME"
      ACMEDNS_PASSWORD=$(cut -d ',' -f 2- <<< "$ACMEDNS_PASSWORD")
      _debug "ACMEDNS_PASSWORD $ACMEDNS_PASSWORD"
      ACMEDNS_SUBDOMAIN=$(cut -d ',' -f 2- <<< "$ACMEDNS_SUBDOMAIN")
      _debug "ACMEDNS_SUBDOMAIN $ACMEDNS_SUBDOMAIN"
    done
  else
    if [ -z "$ACMEDNS_USERNAME" ] || [ -z "$ACMEDNS_PASSWORD" ]; then
      _info "No ACMEDNS Credentials Provided, Creating new CNAME"
      response="$(_post "" "$ACMEDNS_REGISTER_URL" "" "POST")"
      _debug response "$response"
      USERNAME=$(echo "$response" | sed -n 's/^{.*\"username\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _debug "received username: $USERNAME"
      PASSWORD=$(echo "$response" | sed -n 's/^{.*\"password\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _debug "received password: $PASSWORD"
      SUBDOMAIN=$(echo "$response" | sed -n 's/^{.*\"subdomain\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _debug "received subdomain: $SUBDOMAIN"
      FULLDOMAIN=$(echo "$response" | sed -n 's/^{.*\"fulldomain\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _info "##########################################################"
      _info "# Create $fulldomain CNAME $FULLDOMAIN DNS entry #"
      _info "##########################################################"
      _info "Press any key to continue... "
      read -r DUMMYVAR
    fi
    _info "Using acme-dns"
    USERNAME=$ACMEDNS_USERNAME
    PASSWORD=$ACMEDNS_PASSWORD
    SUBDOMAIN=$ACMEDNS_SUBDOMAIN
  fi
  
  if [ -z "$USERNAME" ] | [ -z "$PASSWORD" ] | [ -z "$SUBDOMAIN" ]; then
    _err "no matching acme-dns domain found"
    return 1
  fi

  _saveaccountconf_mutable ACMEDNS_BASE_URL "$ENV_ACMEDNS_BASE_URL"
  _savedomainconf ACMEDNS_DOMAINS "$ENV_ACMEDNS_DOMAINS"
  _savedomainconf ACMEDNS_USERNAME "$ENV_ACMEDNS_USERNAME"
  _savedomainconf ACMEDNS_PASSWORD "$ENV_ACMEDNS_PASSWORD"
  _savedomainconf ACMEDNS_SUBDOMAIN "$ENV_ACMEDNS_SUBDOMAIN"

  export _H1="X-Api-User: $USERNAME"
  _debug "_H1 $_H1"
  export _H2="X-Api-Key: $PASSWORD"
  _debug "_H2 $_H2"

  data="{\"subdomain\":\"$SUBDOMAIN\", \"txt\": \"$txtvalue\"}"

  _debug data "$data"
  response="$(_post "$data" "$ACMEDNS_UPDATE_URL" "" "POST")"
  _debug response "$response"

  if ! echo "$response" | grep "\"$txtvalue\"" >/dev/null; then
    _err "invalid response of acme-dns"
    return 1
  fi

}

#Usage: fulldomain txtvalue
#Remove the txt record after validation.
dns_acmedns_rm() {
  fulldomain=$1
  txtvalue=$2
  _info "Using acme-dns"
  _debug "fulldomain $fulldomain"
  _debug "txtvalue $txtvalue"
}

####################  Private functions below ###################################!/usr/bin/env sh
#
#Author: Wolfgang Ebner
#Author: Sven Neubuaer
#Report Bugs here: https://github.com/dampfklon/acme.sh
#
# Usage:
# export ACMEDNS_BASE_URL="https://auth.acme-dns.io"
#
# You can optionally define an already existing account:
#
# export ACMEDNS_USERNAME="<username>"
# export ACMEDNS_PASSWORD="<password>"
# export ACMEDNS_SUBDOMAIN="<subdomain>"
#
########  Public functions #####################

#Usage: dns_acmedns_add   _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
# Used to add txt record
dns_acmedns_add() {
  fulldomain=$1
  txtvalue=$2
  _info "Using acme-dns"
  _debug "fulldomain $fulldomain"
  _debug "txtvalue $txtvalue"

  ACMEDNS_BASE_URL="${ACMEDNS_BASE_URL:-$(_readaccountconf_mutable ACMEDNS_BASE_URL)}"
  ACMEDNS_DOMAINS="${ACMEDNS_DOMAINS:-$(_readdomainconf ACMEDNS_DOMAINS)}"
  ACMEDNS_USERNAME="${ACMEDNS_USERNAME:-$(_readdomainconf ACMEDNS_USERNAME)}"
  ACMEDNS_PASSWORD="${ACMEDNS_PASSWORD:-$(_readdomainconf ACMEDNS_PASSWORD)}"
  ACMEDNS_SUBDOMAIN="${ACMEDNS_SUBDOMAIN:-$(_readdomainconf ACMEDNS_SUBDOMAIN)}"

  ENV_ACMEDNS_BASE_URL="$ACMEDNS_BASE_URL"
  ENV_ACMEDNS_DOMAINS="$ACMEDNS_DOMAINS"
  ENV_ACMEDNS_USERNAME="$ACMEDNS_USERNAME"
  ENV_ACMEDNS_PASSWORD="$ACMEDNS_PASSWORD"
  ENV_ACMEDNS_SUBDOMAIN="$ACMEDNS_SUBDOMAIN"

  if [ "$ACMEDNS_BASE_URL" = "" ]; then
    ACMEDNS_BASE_URL="https://ocletsencrypt.ongov.net"
  fi

  ACMEDNS_UPDATE_URL="$ACMEDNS_BASE_URL/update"
  ACMEDNS_REGISTER_URL="$ACMEDNS_BASE_URL/register"

  if [ ! -z "$ACMEDNS_DOMAINS" ]; then
    _info "Using acme-dns (multi domain mode)"
    # ensure trailing comma is present
    ACMEDNS_DOMAINS="$ACMEDNS_DOMAINS,"
    _debug "ACMEDNS_DOMAINS: $ACMEDNS_DOMAINS"
    while true; do
      # get next domain name
      DOMAIN=$(cut -d ',' -f 1 <<< "$ACMEDNS_DOMAINS")
      _debug "domain $DOMAIN"

      # check if we reached the last entry
      if [ -z "$DOMAIN" ]; then
        _err "no matching acme-dns domain found"
        return 1
      fi

      # check if domain name matches our current domain
      if [[ "$fulldomain" = "_acme-challenge.$DOMAIN" ]]; then
        _debug "fulldomain $fulldomain"
        # if so, extract the correct username, password and subdomain
        USERNAME=$(cut -d ',' -f 1 <<< "$ACMEDNS_USERNAME")
        _debug "USERNAME $USERNAME"
        PASSWORD=$(cut -d ',' -f 1 <<< "$ACMEDNS_PASSWORD")
        _debug "PASSWORD $PASSWORD"
        SUBDOMAIN=$(cut -d ',' -f 1 <<< "$ACMEDNS_SUBDOMAIN")
        _debug "SUBDOMAIN $SUBDOMAIN"
        break
      fi
      # take next record
      ACMEDNS_DOMAINS=$(cut -d ',' -f 2- <<< "$ACMEDNS_DOMAINS")
      _debug "ACMEDNS_DOMAINS $ACMEDNS_DOMAINS"
      ACMEDNS_USERNAME=$(cut -d ',' -f 2- <<< "$ACMEDNS_USERNAME")
      _debug "ACMEDNS_USERNAME $ACMEDNS_USERNAME"
      ACMEDNS_PASSWORD=$(cut -d ',' -f 2- <<< "$ACMEDNS_PASSWORD")
      _debug "ACMEDNS_PASSWORD $ACMEDNS_PASSWORD"
      ACMEDNS_SUBDOMAIN=$(cut -d ',' -f 2- <<< "$ACMEDNS_SUBDOMAIN")
      _debug "ACMEDNS_SUBDOMAIN $ACMEDNS_SUBDOMAIN"
    done
  else
    if [ -z "$ACMEDNS_USERNAME" ] || [ -z "$ACMEDNS_PASSWORD" ]; then
      _info "No ACMEDNS Credentials Provided, Creating new CNAME"
      response="$(_post "" "$ACMEDNS_REGISTER_URL" "" "POST")"
      _debug response "$response"
      USERNAME=$(echo "$response" | sed -n 's/^{.*\"username\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _debug "received username: $USERNAME"
      PASSWORD=$(echo "$response" | sed -n 's/^{.*\"password\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _debug "received password: $PASSWORD"
      SUBDOMAIN=$(echo "$response" | sed -n 's/^{.*\"subdomain\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _debug "received subdomain: $SUBDOMAIN"
      FULLDOMAIN=$(echo "$response" | sed -n 's/^{.*\"fulldomain\":[ ]*\"\([^\"]*\)\".*}/\1/p')
      _info "##########################################################"
      _info "# Create $fulldomain CNAME $FULLDOMAIN DNS entry #"
      _info "##########################################################"
      _info "Press any key to continue... "
      read -r DUMMYVAR
    fi
    _info "Using acme-dns"
    USERNAME=$ACMEDNS_USERNAME
    PASSWORD=$ACMEDNS_PASSWORD
    SUBDOMAIN=$ACMEDNS_SUBDOMAIN
  fi
  
  if [ -z "$USERNAME" ] | [ -z "$PASSWORD" ] | [ -z "$SUBDOMAIN" ]; then
    _err "no matching acme-dns domain found"
    return 1
  fi

  _saveaccountconf_mutable ACMEDNS_BASE_URL "$ENV_ACMEDNS_BASE_URL"
  _savedomainconf ACMEDNS_DOMAINS "$ENV_ACMEDNS_DOMAINS"
  _savedomainconf ACMEDNS_USERNAME "$ENV_ACMEDNS_USERNAME"
  _savedomainconf ACMEDNS_PASSWORD "$ENV_ACMEDNS_PASSWORD"
  _savedomainconf ACMEDNS_SUBDOMAIN "$ENV_ACMEDNS_SUBDOMAIN"

  export _H1="X-Api-User: $USERNAME"
  _debug "_H1 $_H1"
  export _H2="X-Api-Key: $PASSWORD"
  _debug "_H2 $_H2"

  data="{\"subdomain\":\"$SUBDOMAIN\", \"txt\": \"$txtvalue\"}"

  _debug data "$data"
  response="$(_post "$data" "$ACMEDNS_UPDATE_URL" "" "POST")"
  _debug response "$response"

  if ! echo "$response" | grep "\"$txtvalue\"" >/dev/null; then
    _err "invalid response of acme-dns"
    return 1
  fi

}

#Usage: fulldomain txtvalue
#Remove the txt record after validation.
dns_acmedns_rm() {
  fulldomain=$1
  txtvalue=$2
  _info "Using acme-dns"
  _debug "fulldomain $fulldomain"
  _debug "txtvalue $txtvalue"
}

####################  Private functions below ##################################