include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-connlimit
PKG_VERSION:=1.1
PKG_RELEASE:=1

LUCI_TITLE:=Connection Limit
LUCI_DESCRIPTION:=Per-device concurrent connection limit (nftables connlimit) with ECM/NSS offload auto-exclude for rate-limited devices
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lua-runtime +kmod-nft-connlimit +kmod-qca-nss-ecm
LUCI_PKGARCH:=all

PKG_LICENSE:=MIT

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
