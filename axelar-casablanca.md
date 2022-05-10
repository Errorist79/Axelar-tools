# Manual Setup

## Prerequisites

- Tested On Ubuntu 20.04 LTS 

```
sudo apt-get install wget jq -y
```

## Get Binaries

```bash
# create a temp dir for binaries
mkdir binaries && cd binaries

# get axelard, tofnd binaries and rename
wget -q https://github.com/axelarnetwork/axelar-core/releases/download/v0.17.3/axelard-linux-amd64-v0.17.3
wget -q https://github.com/axelarnetwork/tofnd/releases/download/v0.10.1/tofnd-linux-amd64-v0.10.1
mv axelard-linux-amd64-v0.17.3 axelard
mv tofnd-linux-amd64-v0.10.1 tofnd

# make binaries executable
chmod +x *

# move to usr bin
sudo mv * /usr/bin/

# clean up temp dir
cd .. && rmdir binaries

# check versions
axelard version
tofnd --help
```
## Generate keys

```
axelard keys add broadcaster
axelard keys add validator
tofnd -m create
```

Your `tofnd` secret mnemonic is in a file `.tofnd/export`. Save this mnemonic somewhere safe and delete the file `.tofnd/export`.

## Set environment variables

```bash
echo export CHAIN_ID=axelar-testnet-casablanca-1 >> $HOME/.profile
echo export MONIKER=PUT_YOUR_MONIKER_HERE >> $HOME/.profile
VALIDATOR_OPERATOR_ADDRESS=`axelard keys show validator --bech val --output json | jq -r .address`
BROADCASTER_ADDRESS=`axelard keys show broadcaster --output json | jq -r .address`
echo export VALIDATOR_OPERATOR_ADDRESS=$VALIDATOR_OPERATOR_ADDRESS >> $HOME/.profile
echo export BROADCASTER_ADDRESS=$BROADCASTER_ADDRESS >> $HOME/.profile
```

## Set password 

Protect your keyring password: The following instructions instruct you to store your keyring plaintext password in a file on disk. This instruction is safe only if you can prevent unauthorized access to the file. Use your discretion---substitute your own preferred method for securing your keyring password.

Choose a secret `{KEYRING_PASSWORD}` and add the following line to `$HOME/.profile`:

```bash
echo export KEYRING_PASSWORD=PUT_YOUR_KEYRING_PASSWORD_HERE >> $HOME/.profile
source $HOME/.profile
```
## Configuration

Initialize your Axelar node, fetch configuration, genesis, seeds.
```bash
axelard init $MONIKER --chain-id $CHAIN_ID
```

```bash
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/config.toml -O $HOME/.axelar/config/config.toml
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/configuration/app.toml -O $HOME/.axelar/config/app.toml
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet-2/genesis.json -O $HOME/.axelar/config/genesis.json
wget -q https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/resources/testnet-2/seeds.toml -O -O $HOME/.axelar/config/seeds.toml

# set external ip to your config.json file
sed -i.bak 's/external_address = ""/external_address = "'"$(curl -4 ifconfig.co)"':26656"/g' $HOME/.axelar/config/config.toml
```

## Sync From Snapshot

```bash
axelard unsafe-reset-all
URL="https://snapshots.bitszn.com/snapshots/axelar/axelar.tar"
echo $URL
cd $HOME/.axelar/data
wget -O - $URL | tar -xvf -
cd $HOME
```
## Create services

### axelard
```bash
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
# enabled axelar daemon
sudo systemctl enable axelard
```
### tofnd
```bash
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

# enable tofn daemon
sudo systemctl enable tofnd
```
### vald
```bash
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

#enable val daemon
sudo systemctl enable vald
```
## Start all services

Order of operations:

1. `axelard`: ensure it's fully synced before proceeding
2. `tofnd`: required for `vald`
3. `vald`

```bash
sudo systemctl daemon-reload
sudo systemctl restart axelard
sudo systemctl restart tofnd
sudo systemctl restart vald
```

## Check logs

```bash
# change log settings

sed -i 's/#Storage=auto/Storage=persistent/g' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

journalctl -u axelard.service -f -n 100
journalctl -u tofnd.service -f -n 100
journalctl -u vald.service -f -n 100
```

## Register broadcaster proxy

<Callout emoji="📝">
  Note: Fund your `validator` and `broadcaster` accounts before proceeding.
</Callout>


```bash
axelard tx snapshot register-proxy $BROADCASTER_ADDRESS --from validator --chain-id $CHAIN_ID
```

## Create validator

```bash
### set temporary variables for create-validator command
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
```

## Register external chains

See [Support external chains](https://github.com/axelarnetwork/axelar-docs/tree/main/pages/validator/external-chains).
