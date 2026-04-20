#!/bin/bash

# 1. インスタンスの作成
echo "Creating instances..."
orb create ubuntu kaisobeS
orb create ubuntu kaisobeSW

# 2. リソース設定（Vagrantfile の再現） [cite: 3, 5]
echo "Setting resources..."
orb set cpus 4 kaisobeS
orb set memory 16GiB kaisobeS
orb set cpus 2 kaisobeSW
orb set memory 4GiB kaisobeSW

# 3. 再起動して反映
echo "Restarting instances to apply changes..."
orb restart kaisobeS
orb restart kaisobeSW

# 4. IP アドレスの付与
echo "Configuring network IPs..."
orb -m kaisobeS sudo ip addr add 192.168.56.110/24 dev eth0
orb -m kaisobeSW sudo ip addr add 192.168.56.111/24 dev eth0

# 5. 各ノードのセットアップスクリプト実行 [cite: 1]
echo "Running setup scripts..."
orb -m kaisobeS bash < scripts/setup_server.sh
orb -m kaisobeSW bash < scripts/setup_worker.sh

echo "Cluster is ready!"
orb list
