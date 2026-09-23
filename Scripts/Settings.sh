#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	# 开启 NSS feed（关键）
	echo "CONFIG_FEED_nss_packages=y" >> .config
	echo "CONFIG_FEED_sqm_scripts_nss=y" >> .config

	# NSS 固件
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> .config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> .config

	# 强制启用 NSS 相关模块（建议）
	echo "CONFIG_PACKAGE_kmod-qca-nss-drv=y" >> .config
	echo "CONFIG_PACKAGE_kmod-qca-nss-gmac=y" >> .config
	echo "CONFIG_PACKAGE_kmod-qca-nss-ecm=y" >> .config
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi

	# 99-marvis-tune：启用 ECM mark classifier（限速设备跳过 NSS/ECM 硬件加速）
	# 说明：luci-app-connlimit 内置的 ECM 跳过逻辑（START=98）会在 ECM 加载后
	#       再次幂等启用本 classifier，本 uci-defaults 仅作 first-boot 兜底 +
	#       手动打 mark 示例，两者兼容不冲突。
	ECM_TUNE_DIR="./target/linux/qualcommax/base-files/etc/uci-defaults"
	if [ -d "$ECM_TUNE_DIR" ]; then
		cat > "$ECM_TUNE_DIR/99-marvis-tune" <<'EOF'
#!/bin/sh
# Marvis tune: 启用 ECM mark classifier，使限速设备流量可被 nftables 打 mark 跳过 offload
# eqosplus 的 tc 限速才能命中（ECM/NSS 硬件加速默认会绕过 tc）
# 注意：uci-defaults 阶段 ECM 模块可能未加载，文件不存在时静默跳过；
#       connlimit 会在 START=98 幂等补写，确保真正生效。
[ -f /sys/kernel/debug/ecm/ecm_classifier_mark/enabled ] && echo 1 > /sys/kernel/debug/ecm/ecm_classifier_mark/enabled

# 手动示例（默认注释）：对单台设备 IP 打 0x10 mark，使其流量不被 ECM/NSS offload
# 与 connlimit 内置 ECM 跳过规则同值（0x10），可并存；按需取消注释并替换 IP。
# nft add table inet marvis
# nft add chain inet marvis mark '{ type filter hook prerouting priority 0; policy accept; }'
# nft add rule inet marvis mark ip saddr 192.168.1.100 meta mark set 0x10
# nft add rule inet marvis mark ip daddr 192.168.1.100 meta mark set 0x10
exit 0
EOF
		chmod +x "$ECM_TUNE_DIR/99-marvis-tune"
		echo "99-marvis-tune (ECM mark classifier) created successfully!"
	else
		echo "WARN: $ECM_TUNE_DIR not found, skip 99-marvis-tune"
	fi
fi
