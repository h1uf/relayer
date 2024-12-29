#!/bin/bash
OWNER=$($BINARY --home $GAIA_DATA/ibc-0 keys  show validator -a --keyring-backend="test")

CONTR_CONN=$1
HOST_CONN=$CONTR_CONN
FROM=user
OLD_ENCODING=proto3json
NEW_ENCODING=proto3

#creating IC account for the connection
echo "Creating ica"
$BINARY --home $GAIA_DATA/ibc-0 tx ica controller register $CONTR_CONN --version "{\"version\":\"ics27-1\",\"controller_connection_id\":\"${CONTR_CONN}\",\"host_connection_id\":\"${HOST_CONN}\",\"address\":\"\",\"encoding\":\"${OLD_ENCODING}\",\"tx_type\":\"sdk_multi_msg\"}" --keyring-backend "test" --from $FROM -y
# has to have enough time to finish handshake
sleep 20

ICA_ADDRESS=$($BINARY q ica controller interchain-account $OWNER $CONTR_CONN | cut -d' ' -f2)
echo "ica address ${ICA_ADDRESS}"

# submitting channel upgrade proposal with a new encoding while attacker's channel will se a new encoding
$BINARY --home $GAIA_DATA/ibc-0 tx ibc channel upgrade-channels "{\"version\":\"ics27-1\",\"controller_connection_id\":\"${CONTR_CONN}\",\"host_connection_id\":\"${HOST_CONN}\",\"address\":\"${ICA_ADDRESS}\",\"encoding\":\"${NEW_ENCODING}\",\"tx_type\":\"sdk_multi_msg\"}" --port-pattern "icacontroller-${OWNER}" --expedited --from validator --deposit "10000000000000stake" --title "Channel Upgrades Governance Proposal" --summary "Upgrade icacontroller to use different encoding" --keyring-backend="test" -y
sleep 2
# deposit and vote yes
$BINARY --home $GAIA_DATA/ibc-0  tx gov deposit 1 9999990stake --from validator --keyring-backend test -y
sleep 2
$BINARY --home $GAIA_DATA/ibc-0  tx gov deposit 1 9999990stake --from user --keyring-backend test -y
sleep 2
$BINARY --home $GAIA_DATA/ibc-0  tx gov vote 1 yes --from validator --keyring-backend test -y
sleep 2
$BINARY --home $GAIA_DATA/ibc-0  tx gov vote 1 yes --from user --keyring-backend test -y

sleep 20
# wait for it to pass, I set the waiting period to 30 sec
while :
do
	$BINARY query gov proposal 1 | grep "PASSED" && break || echo "waiting to pass"
	sleep 5
done

echo "proposal passed"