#!/bin/bash
echo -e ''
curl -s https://api.testnet.run/logo.sh | bash && sleep 3
echo -e ''

dependiences () {
    echo -e '\e[0;33mİnstalling Dependiences\e[0m'
    echo -e ''
    sudo apt update
    sudo apt-get install wget liblz4-tool aria2 jq screen -y
}

binaries () {
    # create a temp dir for binaries
    mkdir binaries && cd binaries
    # get axelard, tofnd binaries and rename
    wget -q https://github.com/axelarnetwork/axelar-core/releases/download/v0.17.0/axelard-linux-amd64-v0.17.0
    wget -q https://github.com/axelarnetwork/tofnd/releases/download/v0.9.1/tofnd-linux-amd64-v0.9.1
    mv axelard-linux-amd64-v0.17.0 axelard
    mv tofnd-linux-amd64-v0.9.1 tofnd
    # make binaries executable
    chmod +x *
    # move to usr bin
    sudo mv * /usr/bin/
    # clean up temp dir
    cd .. && rmdir binaries
}

variables (){
    echo export CHAIN_ID=axelar-testnet-lisbon-3 >> $HOME/.profile
    echo export denom=uaxl >> $HOME/.profile
    source $HOME/.profile
    echo -e "\033[1;34m"
if [ ! $node_name ]; then
    read -p ' Enter your node name: ' node_name
    echo 'export node_name='$node_name >> $HOME/.bash_profile
fi
    . $HOME/.bash_profile
    echo -e "\033[0m"
    echo -e "\033[1;34m"
    echo -e ''
    echo -e '#######################################################################'
if [ ! $NODE_PASS ]; then
	read -p ' Enter your node password !!password must be at least 8 characters!!: ' NODE_PASS
    echo 'export node_pass='$NODE_PASS >> $HOME/.bash_profile
    source $HOME/.bash_profile
    source $HOME/.profile
fi
    echo -e ""
    echo -e '\033[0mGenerating keys...\e[0m'
    sleep 2
    echo -e ''
    echo -e "\e[33mWait...\e[0m" && sleep 4
    echo $NODE_PASS | tofnd -m create
    sleep 2
    cat .tofnd/export >> tofnd_key.txt
    sleep 2
    rm .tofnd/export
    echo -e "You can find your tofnd mnemonic with the following command;"
    echo -e "\e[32mcat $HOME/tofnd_key.txt\e[39m"
    (echo $NODE_PASS; echo $NODE_PASS) | axelard keys add validator --output json &>> $HOME/axelar_testnet_validator_info.json
    echo -e "You can find your validator mnemonic with the following command;"
    echo -e "\e[32mcat $HOME/axelar_testnet_validator_info.json\e[39m"
    export AXL_WALLET=`echo $NODE_PASS | axelard keys show validator -a`
    echo 'export AXL_WALLET='${AXL_WALLET} >> $HOME/.bash_profile
    . $HOME/.bash_profile
    echo -e '\n\e[44mHere is the your wallet address, save it!:' $AXL_WALLET '\e[0m\n'
    echo -e "\e[33mWait...\e[0m" && sleep 4
    (echo $NODE_PASS; echo $NODE_PASS) | axelard keys add broadcaster --output json &>> $HOME/axelar_testnet_broadcaster_info.json
    echo -e "You can find your broadcaster mnemonic with the following command;"
    echo -e "\e[32mcat $HOME/axelar_testnet_broadcaster_info.json\e[39m"
    export BROADCASTER_WALLET=`echo $NODE_PASS | axelard keys show broadcaster -a`
    echo 'export BROADCASTER_WALLET='${BROADCASTER_WALLET} >> $HOME/.bash_profile
    . $HOME/.bash_profile
    echo -e '\n\e[44mHere is the your wallet address, save it!:' $BROADCASTER_WALLET '\e[0m\n'
    echo -e "\e[33mWait...\e[0m" && sleep 4 
    export VALIDATOR_OPERATOR_ADDRESS=`echo $NODE_PASS | axelard keys show validator --bech val --output json | jq -r .address`
    echo 'export VALIDATOR_OPERATOR_ADDRESS='${VALIDATOR_OPERATOR_ADDRESS} >> $HOME/.profile
    source $HOME/.profile
}

config () {
    axelard init $node_name --chain-id $CHAIN_ID
    wget https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/config.toml -O $HOME/.axelar/config/config.toml
    wget https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/app.toml -O $HOME/.axelar/config/app.toml
    wget https://axelar-testnet.s3.us-east-2.amazonaws.com/genesis.json -O $HOME/.axelar/config/genesis.json
    wget https://axelar-testnet.s3.us-east-2.amazonaws.com/seeds.txt -O $HOME/.axelar/config/seeds.txt
    # enter seeds to your config.json file
    sed -i.bak 's/seeds = ""/seeds = "'$(cat $HOME/.axelar/config/seeds.txt)'"/g' $HOME/.axelar/config/config.toml
    # set external ip to your config.json file
    sed -i.bak 's/external_address = ""/external_address = "'"$(curl -4 ifconfig.co)"':26656"/g' $HOME/.axelar/config/config.toml
}

snapshot () {
    axelard unsafe-reset-all
    URL=`curl https://quicksync.io/axelar.json | jq -r '.[] |select(.file=="axelartestnet-lisbon-3-pruned")|.url'`
    echo $URL
    FILE=`curl https://quicksync.io/axelar.json | jq -r '.[] |select(.file=="axelartestnet-lisbon-3-pruned")|.filename'`
    echo $FILE
    echo -e 'Downloading snapshot..'
    wget -q $URL
    lz4 -dc --no-sparse $FILE | tar xfC - ~/.axelar
}

services () {

# axelar daemon

sudo tee <<EOF >/dev/null /etc/systemd/system/axelard.service
[Unit]
Description=Axelard Cosmos daemon
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/bin/axelard start
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
sed -i 's/#Storage=auto/Storage=persistent/g' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable axelard
sudo systemctl start axelard

# tofn daemon

sudo tee <<EOF >/dev/null /etc/systemd/system/tofnd.service
[Unit]
Description=Tofnd daemon
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/bin/sh -c 'echo $NODE_PASS | tofnd -m existing -d $HOME/.tofnd'
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable tofnd

# val daemon

sudo tee <<EOF >/dev/null /etc/systemd/system/vald.service
[Unit]
Description=Vald daemon
After=network-online.target
[Service]
User=$USER
ExecStart=/usr/bin/sh -c 'echo $NODE_PASS | /usr/bin/axelard vald-start --validator-addr $VALIDATOR_OPERATOR_ADDRESS --log_level debug --chain-id $CHAIN_ID'
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable vald
}

create_validator () {
if [ ! $faucet ]; then
    echo -e '\e[44mGo to this link https://faucet.testnet.axelar.dev/ then get some tokens for your "broadcaster" and "validator" wallet\e[0m'
    echo -e '\e[42mValidator address\e[0m: '$AXL_WALLET ''
    echo -e 'Broadcaster address '$BROADCASTER_WALLET ''
    echo -e "\033[1;34m"
    read -p 'Then press any key: '
    echo -e "\033[0m"
fi
    echo -e "\033[1;34m"
if [ ! $amount ]; then
    read -p ' Tell me, what is the amount you want to stake?
    remember, 1 AXL=1000000 : ' amount
    echo 'export amount='$amount >> $HOME/.bash_profile
fi
    echo -e "\033[0m"
    source $HOME/.bash_profile
    sleep 2
    wget -q -O axl-dms.sh https://api.testnet.run/axl-dms.sh && chmod +x axl-dms.sh
    sleep 2
    sudo screen -dmS validator ./axl-dms.sh
}


done_process () {
    LOG_SEE="journalctl -u axelard.service -f -n 100"
    source $HOME/.profile
    echo -e '\n\e[41mDone! Now, please wait for your node to sync with the chain. This will take approximately 1h. Use this command to see the logs:' $LOG_SEE '\e[0m\n'
}

additional () {
    echo -e "Axelard logs: journalctl -u axelard.service -f -n 100"
    echo -e "Tofnd logs: journalctl -u tofnd.service -f -n 100"
    echo -e "Vald logs: journalctl -u vald.service -f -n 100"
}

# options

PS3="What do you want?: "
select opt in İnstall Additional quit; 
do

  case $opt in
    İnstall)
    echo -e '\e[1;32mThe installation process begins...\e[0m'
    echo -e ''
    dependiences
    binaries
    variables
    config
    snapshot
    services
    create_validator
    done_process
    sleep 3
      break
      ;;
    Additional)
    echo -e '\e[1;32mAdditional commands...\e[0m'
    echo -e ''
    additional
      ;;
    quit)
    echo -e '\e[1;32mexit...\e[0m' && sleep 1
      break
      ;;
    *) 
      echo "Invalid $REPLY"
      ;;
  esac
done
