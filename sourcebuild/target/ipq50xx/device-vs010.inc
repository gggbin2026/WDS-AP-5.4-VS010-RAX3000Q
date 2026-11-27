
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
  # 🔴 第 22 次：VS010 板级 BDF（board-2.bin）+ 双频段 Q6/m3 固件。
  #    BDF 容器用 qmi-board-id=36/96（沿用 kkstone 已验证路径），
  #    board data 换成从 VS010 0:ART 提取的真实校准（whmzsu oem_extract）。
  DEVICE_PACKAGES := ATH11K_MEM_PROFILE_256M \
	ath11k-firmware-ipq5018 \
	ath11k-firmware-qcn6122 \
	ipq-wifi-cucc_vs010
endef
TARGET_DEVICES += cucc_vs010
