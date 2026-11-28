
define Device/cucc_vs010
  $(call Device/FitImage)
  $(call Device/UbiFit)
  SOC := ipq5000
  DEVICE_VENDOR := CUCC
  DEVICE_MODEL := VS010
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  DEVICE_DTS_CONFIG := config@mp02.1
  IMAGES := nand-factory.ubi
  # 🔴 r29.6：DEVICE_PACKAGES 里绝不写内存档符号（它不是包名）。
  #   256M 内存档由 .config 的对应符号驱动，
  #   image/Makefile 的 DTS_CPPFLAGS 条件语句自动加宏，
  #   写进包列表只会引入一个不存在的包依赖（3000Q 定义里没有，故 3000Q 编译成功）。
  DEVICE_PACKAGES := \
	ath11k-firmware-ipq5018 \
	ath11k-firmware-qcn6122 \
	ipq-wifi-cucc_vs010
endef
TARGET_DEVICES += cucc_vs010
