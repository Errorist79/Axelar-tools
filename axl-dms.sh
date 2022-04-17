#!/bin/bash
source $HOME/.profile
source $HOME/.bash_profile
check=0
while [ $check -le 1 ]
do
    tof=$(curl -s localhost:26657/status | jq '.result.sync_info.catching_up')
    if [ "$tof" = "false" ]; then
        echo -e '\e[32mDone!, we will create the validator shortly, just wait\e[0m'
        check=2
    else
        echo -e '\e[32mStill syncing, please wait...\e[0m'
    fi
sleep 80
done
sudo systemctl start tofnd
sudo systemctl start vald
sleep 2
echo $node_pass | axelard tx snapshot register-proxy $BROADCASTER_WALLET --from validator --chain-id $CHAIN_ID
sleep 2
echo $node_pass | axelard tx staking create-validator --yes --amount $amount$denom --moniker $node_name --commission-rate "0.10" --commission-max-rate "0.20" --commission-max-change-rate "0.01" --min-self-delegation "1" --pubkey "$(axelard tendermint show-validator)" --from validator --chain-id $CHAIN_ID
sleep 10
