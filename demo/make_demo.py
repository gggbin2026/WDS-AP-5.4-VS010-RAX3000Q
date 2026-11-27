import pathlib,json,shutil
R=pathlib.Path('_r28/sourcebuild/files/www'); D=pathlib.Path('demo')
D.mkdir(exist_ok=True)
JS=(R/'vs010-setup.js').read_text()
LINKS={"ok":1,"links":[
  {"lan":"内网LAN1","if":"eth0","speed":1000,"duplex":"full","src":"phy"},
  {"lan":"内网LAN2","if":"eth1","speed":1000,"duplex":"full","src":"phy"}],
 "wifi_temp":{"c":46,"has":True,"src":"ath11k phy0 thermal"},
 "net":{"admin_ip":"172.10.10.241","proto":"static","link_local":"169.254.240.1/16",
  "bridge":{"name":"br-lan","members":"eth0 eth1","stp":"1"},"dhcp_server":"off",
  "gateway":"172.10.8.1","dns":"172.10.8.1","firewall":"已彻底关闭","watchdog":"0",
  "ipv6":"0","mode":"wds","host":"WDS-Z","board":"cucc_vs010","role":"ap"}}
SYS={"cpu_usage_pct":18,"mem_used_pct":42,"temp_has":True,"temp_c":54,
 "cpu_has_freq":True,"cpu_mhz":864,"cpu_mhz_min":216,"cpu_mhz_max":864,"cpu_cores":2,
 "load1":0.12,"load5":0.18,"load15":0.15,"mem_has":True,"mem_avail":"236 MB",
 "mem_avail_kb":241664,"mem_total":"512 MB","mem_used":"276 MB","swap_total_kb":0,
 "wifi_temp_c":"46 °C"}
BRIDGE={"ok":1,"refresh":10,"host":"WDS-Z","model":"cucc_vs010 / VS010","admin_ip":"172.10.10.241",
 "uptime":"2 天 04:17","time":"2026-11-28 15:42:08","time_synced":True,"sys":SYS,
 "bridge":{"name":"br-lan","members":"eth0 eth1","stp":"1"},
 "wds":{"role":"ap","iface":"ath1","mode":"ap/wds","ssid":"WDS-Bridge-Z",
  "peer_mac":"aa:bb:cc:dd:ee:ff","peer_ip":"172.10.10.242","peer_ping_ok":True,"associated":True},
 "watchdog":{"enabled":"0","dryrun":"1","delay":5,"grace":6,"down_sec":0,"left_sec":"-"},
 "rf":{"has_signal":True,"signal":-52,"quality_pct":84,"quality":"优","signal_avg":-53,
  "noise":-96,"snr":43,"link_budget_db":21,"dist_text":"约 12 m","dist_note":"信号良好",
  "tx_mbps":866,"rx_mbps":780,"width":"160 MHz","mcs":"11","channel":"36","freq":5180,
  "txpower":23,"tx_packets":12093,"retry_pct":1.2,"retries":145,"failed":2,"inactive_ms":120},
 "stations":[],"diag":{"phy_count":2,"phy_list":"phy0 / phy1","modules":"ath11k / qca-nss-dp",
  "dt_board_id":"0x24 / 0x60","dt_bdf_addr":"0x1000 / 0x26800","role":"ap","role_note":"WDS 主",
  "hint":"BDF 来自本机 ART","dmesg":"ath11k: board-2.bin loaded"},
 "accel":{"state":"未启用","nss_drv":1,"qca_wifi":1,"ath11k":1,"hint":"纯二层桥不做三层转发",
  "modules":"qca-nss-dp","rules":"0","dmesg":"ok"},
 "switch":{"dev":"switch0","type":"QCA8337"},"build":"5.4-r28-20261128-1542",
 "gateway":"172.10.8.1","dns":"172.10.8.1","board":"cucc_vs010",
 "notes":["WDS 主 / 客户端两端都绝不能开 DHCP 服务端","只读状态无需登录；修改配置需登录"]}
AP={"ok":1,"model":"cucc_vs010 / VS010","admin_ip":"172.10.10.241","uptime":"1 天 09:33",
 "time":"2026-11-28 15:42:08","sys":SYS,"build":"5.4-r28-20261128-1542",
 "radios":[{"band":"2.4G","ssid":"VS010-AP-2G","channel":"auto","txpower":20,
   "clients":[{"mac":"aa:bb:cc:11:22:33","signal":-48,"pct":88}]},
  {"band":"5G","ssid":"VS010-AP-5G","channel":"36","txpower":23,
   "clients":[{"mac":"aa:bb:cc:44:55:66","signal":-55,"pct":76}]}],
 "guard":{"enabled":True,"mode":"kick","rssi":-70,"timeout":10,"log":"弱信号剔除守护运行中"},
 "bdf":{"board_id":"0x24 / 0x60","file":"board-2.bin","size":"131072 B","hint":"本机 ART 校准"},
 "accel":{"state":"未启用","hint":"哑 AP 不做三层转发"},
 "dhcp_server":"off","gateway":"172.10.8.1","dns":"172.10.8.1","ipv6":"0",
 "firewall":"已彻底关闭","watchdog":"0","host":"VS010-AP","board":"cucc_vs010",
 "proto":"static","link_local":"169.254.240.1/16",
 "bridge":{"name":"br-lan","members":"eth0 eth1","stp":"1"}}
STATE={"ok":1,"mode":"wds","role":"ap","ip":"172.10.10.241","ap_ssid":"VS010-AP",
 "ap_key":"AP123456","ap2_ssid":"","ap2_key":"","ap5_ssid":"","ap5_key":"",
 "wds_ssid":"WDS-Bridge-Z","wds_key":"WDS123456","peer_ssid":"","peer_key":"","peer_bssid":"",
 "ch5g":"auto","ch24g":"auto","htmode":"HT160","txpower":"auto","wmm":"1","mumimo":"1",
 "weak_rssi":"-70","weak_timeout":"10","mgmt_ip":"172.10.10.241","mgmt_mask":"255.255.252.0",
 "hostname":"WDS-Z","stp":"1","ntp_server":"172.10.10.254","ntp_interval":"300","theme":"argon",
 "defaults":{"ap_ssid":"VS010-AP","ap_key":"AP123456","wds_ssid":"WDS-Bridge-Z","wds_key":"WDS123456",
  "ch5g":"auto","ch24g":"auto","htmode":"HT160","txpower":"auto","wmm":"1","mumimo":"1",
  "weak_rssi":"-70","weak_timeout":"10","mgmt_ip":"172.10.10.241","mgmt_mask":"255.255.252.0",
  "stp":"1","ntp_interval":"300","theme":"argon"}}
MOCK='''<script>
/* 演示用：把 CGI 请求映射到内置样例数据，页面本身零改动 */
(function(){
  var DATA=__DATA__;
  window.fetch=function(url,opt){
    url=String(url||''); var d;
    if(url.indexOf('/cgi-bin/vs010?')>=0) d=DATA.mode||{ok:1,mode:'wds'};
    else if(url.indexOf('vs010_setup/probe')>=0) d={ok:1};
    else if(url.indexOf('vs010_setup/state')>=0) d=DATA.state;
    else if(url.indexOf('vs010-links')>=0) d=DATA.links;
    else if(url.indexOf('cgi-bin/bridge')>=0) d=DATA.bridge;
    else if(url.indexOf('cgi-bin/apstatus')>=0) d=DATA.ap;
    else if(url.indexOf('cgi-bin/vs010')>=0) d=DATA.mode||{ok:1,mode:'wds'};
    else d={ok:1};
    return Promise.resolve({ok:true,status:200,json:function(){return Promise.resolve(d)},
      text:function(){return Promise.resolve(JSON.stringify(d))}});
  };
})();
</script>'''
BANNER='<div style="position:sticky;top:0;z-index:999;background:#7a5cf0;color:#fff;padding:6px 12px;font-size:12px;text-align:center">🎬 r28 界面演示 · 内置样例数据（非真实设备）</div>'
for pg,mode in [('bridge','wds'),('ap','ap')]:
    s=(R/pg/'index.html').read_text()
    s=s.replace('<script src="../vs010-setup.js"></script>','<script>\n'+JS+'\n</script>',1)
    data={"mode":{"ok":1,"mode":mode},"state":STATE,"links":LINKS,"bridge":BRIDGE,"ap":AP}
    inj=MOCK.replace('__DATA__',json.dumps(data,ensure_ascii=False))
    s=s.replace('</head>',inj+'</head>',1).replace('<body>','<body>\n'+BANNER,1)
    (D/f'{pg}.html').write_text(s)
    print('  ✅ demo/'+pg+'.html',len(s),'B')
# HTTP 站点
S=D/'site'; shutil.rmtree(S,ignore_errors=True)
(S/'bridge').mkdir(parents=True); (S/'ap').mkdir(); (S/'cgi-bin').mkdir()
shutil.copyfile(R/'index.html',S/'index.html')
shutil.copyfile(D/'bridge.html',S/'bridge/index.html')
shutil.copyfile(D/'ap.html',S/'ap/index.html')
(S/'cgi-bin/vs010').write_text('{"ok":1,"mode":"wds"}')
print('  ✅ HTTP 演示站点 demo/site/ 就绪')
