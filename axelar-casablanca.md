sudo apt-get install wget jq -y
mkdir binaries && cd binaries

## get binaries
wget -q https://github.com/axelarnetwork/axelar-core/releases/download/v0.17.3/axelard-linux-amd64-v0.17.3
wget -q https://github.com/axelarnetwork/tofnd/releases/download/v0.10.1/tofnd-linux-amd64-v0.10.1
mv axelard-linux-amd64-v0.17.3 axelard
mv tofnd-linux-amd64-v0.10.1 tofnd

chmod +x *
sudo mv * /usr/bin/
cd .. && rmdir binaries

## create keys
axelard keys add broadcaster
axelard keys add validator
tofnd -m create

## set variables
echo export CHAIN_ID=axelar-testnet-casablanca-1 >> $HOME/.profile
echo export MONIKER=PUT_YOUR_MONIKER_HERE >> $HOME/.profile
VALIDATOR_OPERATOR_ADDRESS=`axelard keys show validator --bech val --output json | jq -r .address`
BROADCASTER_ADDRESS=`axelard keys show broadcaster --output json | jq -r .address`
echo export VALIDATOR_OPERATOR_ADDRESS=$VALIDATOR_OPERATOR_ADDRESS >> $HOME/.profile
echo export BROADCASTER_ADDRESS=$BROADCASTER_ADDRESS >> $HOME/.profile

## set password 
echo export KEYRING_PASSWORD=PUT_YOUR_KEYRING_PASSWORD_HERE >> $HOME/.profile
source $HOME/.profile

axelard init $MONIKER --chain-id $CHAIN_ID

## configuration
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/config.toml -O $HOME/.axelar/config/config.toml
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/app.toml -O $HOME/.axelar/config/app.toml
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet-2/genesis.json -O $HOME/.axelar/config/genesis.json
wget -q https://raw.githubusercontent.com/Errorist79/seeds/main/axl-2-seed.txt -O $HOME/.axelar/config/seeds.txt

sed -i.bak 's/seeds = ""/seeds = "'$(cat $HOME/.axelar/config/seeds.txt)'"/g' $HOME/.axelar/config/config.toml
sed -i.bak 's/external_address = ""/external_address = "'"$(curl -4 ifconfig.co)"':26656"/g' $HOME/.axelar/config/config.toml

## quick sync
axelard unsafe-reset-all
URL="https://snapshots.bitszn.com/snapshots/axelar/axelar.tar"
echo $URL
cd $HOME/.axelar/data
wget -O - $URL | tar -xvf -
cd $HOME

## services

# axelard
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

sudo systemctl enable axelard

# tofnd
sudo tee <<EOF >/dev/null /etc/systemd/system/tofnd.service
[Unit]
Description=Tofnd daemon
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/bin/sh -c 'echo $KEYRING_PASSWORD | tofnd -m existing -d $HOME/.tofnd'
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable tofnd

# vald
sudo tee <<EOF >/dev/null /etc/systemd/system/vald.service
[Unit]
Description=Vald daemon
After=network-online.target
[Service]
User=$USER
ExecStart=/usr/bin/sh -c 'echo $KEYRING_PASSWORD | /usr/bin/axelard vald-start --validator-addr $VALIDATOR_OPERATOR_ADDRESS --log_level debug --chain-id $CHAIN_ID --from broadcaster'
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable vald

## start services
sudo systemctl daemon-reload
sudo systemctl restart axelard
sudo systemctl restart tofnd
sudo systemctl restart vald

# change log settings
sed -i 's/#Storage=auto/Storage=persistent/g' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

journalctl -u axelard.service -f -n 100
journalctl -u tofnd.service -f -n 100
journalctl -u vald.service -f -n 100

## register broadcaster proxy
axelard tx snapshot register-proxy $BROADCASTER_ADDRESS --from validator --chain-id $CHAIN_ID

## create validator
# set temporary variables for create-validator command
IDENTITY="YOUR_KEYBASE_IDENTITY"
AMOUNT=PUT_AMOUNT_OF_TOKEN_YOU_WANT_TO_DELEGATE
DENOM=uaxl

axelard tx staking create-validator --yes \
 --amount $AMOUNT$DENOM \
 --moniker $MONIKER \
 --commission-rate="0.10" \
 --commission-max-rate="0.20" \
 --commission-max-change-rate="0.01" \
 --min-self-delegation="1" \
 --pubkey="$(axelard tendermint show-validator)" \
 --from validator \
 -b block \
 --identity=$IDENTITY \
 --chain-id $CHAIN_ID
