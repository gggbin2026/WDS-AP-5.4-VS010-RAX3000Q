		// QCA8337 —— r23 默认档：3000Q 已验证值（用户实机「网卡都能起来」）
		// 🔴 切到实机 OEM 档：跑 tools/apply-vs010-switch-oem.py
		//    或在 workflow 里把 vs010_switch_oem 设为 true
		// BEGIN_SWITCH_OEM
		ess-switch1@1 {
			compatible = "qcom,ess-switch-qca83xx";
			device_id = <1>;

			reset_gpio = <26>;

			switch_access_mode = "mdio";
			mdio-bus = <&mdio1>;

			qca,ar8327-initvals = <
				0x000c 0x00000080  // PAD6_MODE = MAC6_SGMII_EN
				0x0010 0x002613a0  // PWS_REG = DEFAULT_VALUE | SERDES_AEN
				0x0094 0x000010ce  // PORT6_STATUS = DEFAULT_VALUE | DUPLEX_MODE_6 | RXMAC_EN_6 |
						   //                TXMAC_EN_6 | SPEED_6(1000M)
				0x00e0 0xc74164de  // SGMII_CTRL = DEFAULT_VALUE | MODE_CTRL_25M(SGMII_PHY) | SGMII_EN_SD |
						   //              SGMII_EN_TX | SGMII_EN_RX | SGMII_EN_PLL
			>;

			switch_cpu_bmp = <0x48>;  // CPU port bitmap: 3 6
			switch_lan_bmp = <0x34>;  // LAN port bitmap: 2 4 5
			switch_wan_bmp = <0x02>;  // WAN port bitmap: 1

			qcom,port_phyinfo {
				// MAC1 -> Phy0 -> WAN
				port@1 {
					port_id = <1>;
					phy_address = <0>;
				};

				// MAC2 -> Phy1 -> LAN1
				port@2 {
					port_id = <2>;
					phy_address = <1>;
				};

				// MAC3 -> Phy2 -> IPQ5000 GE Phy
				port@3 {
					port_id = <3>;
					phy_address = <2>;
				};

				// MAC4 -> Phy3 -> LAN2
				port@4 {
					port_id = <4>;
					phy_address = <3>;
				};

				// MAC5 -> Phy4 -> LAN3
				port@5 {
					port_id = <5>;
					phy_address = <4>;
				};

				// MAC6 ---SGMII---> IPQ5000 MAC1
				port@6 {
					port_id = <6>;

					forced-speed = <1000>;
					forced-duplex = <1>;
				};
			};
		};
		// END_SWITCH_OEM
